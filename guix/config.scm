(use-modules
  (gnu)
  (gnu packages certs)
  (nongnu packages linux)
  (nongnu system linux-initrd)
  (gnu services networking)
  (gnu services desktop)
  (gnu services sound)
  (guix channels))


(operating-system
  (kernel linux)
  (firmware (list linux-firmware amdgpu-firmware))
  (initrd microcode-initrd)
  (locale "en_US.utf8")
  (timezone "Asia/Shanghai")
  (keyboard-layout (keyboard-layout "us"))
  (host-name "guix")

  (users (cons (user-account
		 (name "cc1")
		 (comment "cc1")
		 (group "users")
		 (home-directory "/home/cc1")
		 (supplementary-groups '("wheel" "netdev" "audio" "video")))
	       %base-user-accounts))

  (packages (append (list nss-certs) %base-packages))

  (services (cons* (service elogind-service-type
			    (elogind-configuration
			      (handle-power-key 'ignore)))
		   (service wpa-supplicant-service-type)
		   (service network-manager-service-type)
		   (service alsa-service-type)
		   (modify-services %base-services
				    (guix-service-type
				      config => (guix-configuration
						  (inherit config)
						  (channels (cons (channel
								    (name 'nonguix)
								    (url "https://gitlab.com/nonguix/nonguix"))
								  %default-channels))
						  (http-proxy "http://127.0.0.1:7890"))))))

  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (targets (list "/boot/efi"))
                (keyboard-layout keyboard-layout)))
  (swap-devices (list (swap-space (target (uuid "e5c87fb2-e8f8-4c7f-b659-0d0d0d33bd74")))))

  (file-systems (cons* (file-system
                         (mount-point "/boot/efi")
                         (device (uuid "6993-ABCD" 'fat32))
                         (type "vfat"))
                       (file-system
                         (mount-point "/")
                         (device (uuid "6150dc3b-0816-4215-88a8-250a3fedb748" 'ext4))
                         (type "ext4"))
		       %base-file-systems)))
