self: super: {
  dockerTools = super.dockerTools // {

  # 1. extract the base image
  # 2. create the layer
  # 3. add layer deps to the layer itself, diffing with the base image
  # 4. compute the layer id
  # 5. put the layer in the image
  # 6. repack the image
  buildImage = super.lib.makeOverridable (
    args@{
      # Image name.
      name
    , # Image tag, when null then the nix output hash will be used.
      tag ? null
    , # Parent image, to append to.
      fromImage ? null
    , # Name of the parent image; will be read from the image otherwise.
      fromImageName ? null
    , # Tag of the parent image; will be read from the image otherwise.
      fromImageTag ? null
    , # Files to put on the image (a nix store path or list of paths).
      copyToRoot ? null
    , # When copying the contents into the image, preserve symlinks to
      # directories (see `rsync -K`).  Otherwise, transform those symlinks
      # into directories.
      keepContentsDirlinks ? false
    , # Docker config; e.g. what command to run on the container.
      config ? null
    , # Image architecture, defaults to the architecture of the `hostPlatform` when unset
      architecture ? null
    , # Optional bash script to run on the files prior to fixturizing the layer.
      extraCommands ? ""
    , uid ? 0
    , gid ? 0
    , # Optional bash script to run as root on the image when provisioning.
      runAsRoot ? null
    , # Size of the virtual machine disk to provision when building the image.
      diskSize ? 1024
    , # Size of the virtual machine memory to provision when building the image.
      buildVMMemorySize ? 512
    , # Time of creation of the image.
      created ? "1970-01-01T00:00:01Z"
    , # Compressor to use. One of: none, gz, zstd.
      compressor ? "gz"
      # Populate the nix database in the image with the dependencies of `copyToRoot`.
    , includeNixDB ? false
    , # Deprecated.
      contents ? null
    ,
    }:

    let
      # OVERLAY: these 2 lines are added to the original function
      inherit (super) lib pigz zstd jq jshon moreutils writeText runCommand mkDbExtraCommand writeClosure;
      inherit (super.dockerTools) mkPureLayer mkRootLayer;

      compressors = {
        none = {
          ext = "";
          nativeInputs = [ ];
          compress = "cat";
          decompress = "cat";
        };
        gz = {
          ext = ".gz";
          nativeInputs = [ pigz ];
          compress = "pigz -p$NIX_BUILD_CORES -nTR";
          decompress = "pigz -d -p$NIX_BUILD_CORES";
        };
        zstd = {
          ext = ".zst";
          nativeInputs = [ zstd ];
          compress = "zstd -T$NIX_BUILD_CORES";
          decompress = "zstd -d -T$NIX_BUILD_CORES";
        };
      };

      compressorForImage = compressor: imageName: compressors.${compressor} or
        (throw "in docker image ${imageName}: compressor must be one of: [${toString builtins.attrNames compressors}]");

      checked =
        lib.warnIf (contents != null)
          "in docker image ${name}: The contents parameter is deprecated. Change to copyToRoot if the contents are designed to be copied to the root filesystem, such as when you use `buildEnv` or similar between contents and your packages. Use copyToRoot = buildEnv { ... }; or similar if you intend to add packages to /bin."
        lib.throwIf (contents != null && copyToRoot != null) "in docker image ${name}: You can not specify both contents and copyToRoot."
        ;

      rootContents = if copyToRoot == null then contents else copyToRoot;

      baseName = baseNameOf name;

      # Create a JSON blob of the configuration. Set the date to unix zero.
      baseJson =
        let
          pure = writeText "${baseName}-config.json" (builtins.toJSON {
            inherit created config architecture;
            preferLocalBuild = true;
            os = "linux";
          });
          impure = runCommand "${baseName}-config.json"
            {
              nativeBuildInputs = [ jq ];
              preferLocalBuild = true;
            }
            ''
              jq ".created = \"$(TZ=utc date --iso-8601="seconds")\"" ${pure} > $out
            '';
        in
        if created == "now" then impure else pure;

      compress = compressorForImage compressor name;

      # TODO: add the dependencies of the config json.
      extraCommandsWithDB =
        if includeNixDB then (mkDbExtraCommand rootContents) + extraCommands
        else extraCommands;

      layer =
        if runAsRoot == null
        then
          mkPureLayer
            {
              name = baseName;
              inherit baseJson keepContentsDirlinks uid gid;
              extraCommands = extraCommandsWithDB;
              copyToRoot = rootContents;
            } else
          mkRootLayer {
            name = baseName;
            inherit baseJson fromImage fromImageName fromImageTag
              keepContentsDirlinks runAsRoot diskSize buildVMMemorySize;
            extraCommands = extraCommandsWithDB;
            copyToRoot = rootContents;
          };
      result = runCommand "docker-image-${baseName}.tar${compress.ext}"
        {
          nativeBuildInputs = [ jshon jq moreutils ] ++ compress.nativeInputs;
          # Image name must be lowercase
          imageName = lib.toLower name;
          imageTag = lib.optionalString (tag != null) tag;
          inherit fromImage baseJson;
          layerClosure = writeClosure [ layer ];
          passthru.buildArgs = args;
          passthru.layer = layer;
          passthru.imageTag =
            if tag != null
            then tag
            else
              lib.head (lib.strings.splitString "-" (baseNameOf (builtins.unsafeDiscardStringContext result.outPath)));
        } ''
        ${lib.optionalString (tag == null) ''
          outName="$(basename "$out")"
          outHash=$(echo "$outName" | cut -d - -f 1)

          imageTag=$outHash
        ''}

        # Print tar contents:
        # 1: Interpreted as relative to the root directory
        # 2: With no trailing slashes on directories
        # This is useful for ensuring that the output matches the
        # values generated by the "find" command
        ls_tar() {
          for f in $(tar -tf $1 | xargs realpath -ms --relative-to=.); do
            if [[ "$f" != "." ]]; then
              echo "/$f"
            fi
          done
        }

        mkdir image
        touch baseFiles
        baseEnvs='[]'
        if [[ -n "$fromImage" ]]; then
          echo "Unpacking base image..."
          tar -C image -xpf "$fromImage"

          # Store the layers and the environment variables from the base image
          cat ./image/manifest.json  | jq -r '.[0].Layers | .[]' > layer-list
          configName="$(cat ./image/manifest.json | jq -r '.[0].Config')"
          baseEnvs="$(cat "./image/$configName" | jq '.config.Env // []')"

          # Extract the parentID from the manifest
          if [[ -n "$fromImageName" ]] && [[ -n "$fromImageTag" ]]; then
            parentID="$(
              cat "image/manifest.json" |
                jq -r '.[] | select(.RepoTags | contains([$desiredTag])) | rtrimstr(".json")' \
                  --arg desiredTag "$fromImageName:$fromImageTag"
            )"
          else
            echo "From-image name or tag wasn't set. Reading the first ID."
            parentID="$(cat "image/manifest.json" | jq -r '.[0].Config | rtrimstr(".json")')"
          fi

          # Otherwise do not import the base image configuration and manifest
          chmod a+w image image/*.json
          rm -f image/*.json

          for l in image/*/layer.tar; do
            ls_tar $l >> baseFiles
          done
        else
          touch layer-list
        fi

        chmod -R ug+rw image

        mkdir temp
        cp ${layer}/* temp/
        chmod ug+w temp/*

        for dep in $(cat $layerClosure); do
          find $dep >> layerFiles
        done

        echo "Adding layer..."
        # Record the contents of the tarball with ls_tar.
        ls_tar temp/layer.tar >> baseFiles

        # OVERLAY: the /nix/var/nix folder is required for nix commands
        mkdir -p ./nix/var/nix
        echo "./nix/var" >> layerFiles
        echo "./nix/var/nix" >> layerFiles

        # OVERLAY: add current packages into /gcroots to protect them from garbage collection
        #gcroots="./nix/var/nix/gcroots"
        #mkdir -p $gcroots
        #echo $gcroots >> layerFiles
        #for path in $(cat $layerClosure); do
        #  gcroot="$gcroots/$(basename $path)"
        #  ln -s $path $gcroot
        #  find $gcroot >> layerFiles
        #done

        # Append nix/store directory to the layer so that when the layer is loaded in the
        # image /nix/store has read permissions for non-root users.
        # nix/store is added only if the layer has /nix/store paths in it.
        if [ $(wc -l < $layerClosure) -gt 1 ] && [ $(grep -c -e "^/nix/store$" baseFiles) -eq 0 ]; then
          mkdir -p ./nix/store
          chmod -R 555 nix
          echo "./nix" >> layerFiles
          echo "./nix/store" >> layerFiles
        fi

        # Get the files in the new layer which were *not* present in
        # the old layer, and record them as newFiles.
        comm <(sort -n baseFiles|uniq) \
             <(sort -n layerFiles|uniq|grep -v ${layer}) -1 -3 > newFiles

        # OVERLAY: modify mode for these folders
        chmod u+w ./nix/store
        chmod -R u+w ./nix/var

        # Append the new files to the layer.
        # OVERLAY: modify owner and group for these additional files
        tar -rpf temp/layer.tar --hard-dereference --sort=name --mtime="@$SOURCE_DATE_EPOCH" \
          --owner=1000 --group=100 --no-recursion --verbatim-files-from --files-from newFiles

        echo "Adding meta..."

        # If we have a parentID, add it to the json metadata.
        if [[ -n "$parentID" ]]; then
          cat temp/json | jshon -s "$parentID" -i parent > tmpjson
          mv tmpjson temp/json
        fi

        # Take the sha256 sum of the generated json and use it as the layer ID.
        # Compute the size and add it to the json under the 'Size' field.
        layerID=$(sha256sum temp/json|cut -d ' ' -f 1)
        size=$(stat --printf="%s" temp/layer.tar)
        cat temp/json | jshon -s "$layerID" -i id -n $size -i Size > tmpjson
        mv tmpjson temp/json

        # Use the temp folder we've been working on to create a new image.
        mv temp image/$layerID

        # Add the new layer ID to the end of the layer list
        (
          cat layer-list
          # originally this used `sed -i "1i$layerID" layer-list`, but
          # would fail if layer-list was completely empty.
          echo "$layerID/layer.tar"
        ) | sponge layer-list

        # Create image json and image manifest
        imageJson=$(cat ${baseJson} | jq '.config.Env = $baseenv + .config.Env' --argjson baseenv "$baseEnvs")
        imageJson=$(echo "$imageJson" | jq ". + {\"rootfs\": {\"diff_ids\": [], \"type\": \"layers\"}}")
        manifestJson=$(jq -n "[{\"RepoTags\":[\"$imageName:$imageTag\"]}]")

        for layerTar in $(cat ./layer-list); do
          layerChecksum=$(sha256sum image/$layerTar | cut -d ' ' -f1)
          imageJson=$(echo "$imageJson" | jq ".history |= . + [{\"created\": \"$(jq -r .created ${baseJson})\"}]")
          # diff_ids order is from the bottom-most to top-most layer
          imageJson=$(echo "$imageJson" | jq ".rootfs.diff_ids |= . + [\"sha256:$layerChecksum\"]")
          manifestJson=$(echo "$manifestJson" | jq ".[0].Layers |= . + [\"$layerTar\"]")
        done

        imageJsonChecksum=$(echo "$imageJson" | sha256sum | cut -d ' ' -f1)
        echo "$imageJson" > "image/$imageJsonChecksum.json"
        manifestJson=$(echo "$manifestJson" | jq ".[0].Config = \"$imageJsonChecksum.json\"")
        echo "$manifestJson" > image/manifest.json

        # Store the json under the name image/repositories.
        jshon -n object \
          -n object -s "$layerID" -i "$imageTag" \
          -i "$imageName" > image/repositories

        # Make the image read-only.
        chmod -R a-w image

        echo "Cooking the image..."
        tar -C image --hard-dereference --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --xform s:'^./':: -c . | ${compress.compress} > $out

        echo "Finished."
      '';

    in
    checked result
  );
};
}

