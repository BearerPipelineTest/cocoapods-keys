module CocoaPodsKeys
  class Installer
    def initialize(sandbox_root)
      @sandbox_root = sandbox_root
    end

    def install!
      require 'key_master'
      require 'keyring_liberator'

      keyring = KeyringLiberator.get_keyring(Dir.getwd)

      return unless keyring

      Pod::UI.section 'Adding keys' do
        key_master = KeyMaster.new(keyring)

        keys_folder = File.join(@sandbox_root, 'Keys')
        keys_headers_folder = File.join(@sandbox_root, 'Headers', 'Public', 'CocoaPods-Keys')
        interface_file = File.join(keys_headers_folder, key_master.name + '.h')
        implementation_file = File.join(keys_folder, key_master.name + '.m')
        Dir.mkdir keys_folder unless Dir.exists? keys_folder
        Dir.mkdir keys_headers_folder unless Dir.exists? keys_headers_folder
        File.open(interface_file, 'w') { |f| f.write(key_master.interface) }
        File.open(implementation_file, 'w') { |f| f.write(key_master.implementation) }

        project = Xcodeproj::Project.open File.join(@sandbox_root, 'Pods.xcodeproj')

        group = project.new_group('Keys')
        group.new_file(interface_file)
        implementation = group.new_file(implementation_file)

        pods_target = project.targets.detect { |t| t.name == 'Pods' }
        unless pods_target
          pods_target = project.targets.detect { |t| t.name == 'Pods-' + keyring.name }
        end

        # Swift Pod support
        if pods_target.product_type == "com.apple.product-type.framework"
          headers_build_phase = pods_target.build_phases.detect { |t| t.isa == 'PBXHeadersBuildPhase' }
          pods_target.add_file_references [implementation]

        else
          pods_target.add_file_references [implementation]
        end

        project.save
      end
    end
  end
end
