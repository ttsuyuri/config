;; This is an operating system configuration generated
;; by the graphical installer.
;;
;; Once installation is complete, you can learn and modify
;; this file to tweak the system configuration, and pass it
;; to the 'guix system reconfigure' command to effect your
;; changes.


;; Indicate which modules to import to access the variables
;; used in this configuration.
(use-modules
 (gnu)
 (gnu packages)
 (gnu packages compression)
 (gnu packages cpio)
 (gnu packages linux)
 (gnu packages wm)
 (guix packages)
 (guix gexp)
 (guix utils)
 (guix build-system gnu)
 (guix build-system linux-module)
 (guix git-download)
 (guix licenses)
 (guix download)
 (srfi srfi-1)
 (rnrs lists))
(use-service-modules desktop sddm xorg)

(define %default-extra-linux-options
  (@@ (gnu packages linux) %default-extra-linux-options))

(define license (@@ (guix licenses) license))

(define config->string
  (@@ (gnu packages linux) config->string))

(define* (nonfree uri #:optional (comment ""))
  "Return a nonfree license, whose full text can be found
at URI, which may be a file:// URI pointing the package's tree."
  (license "Nonfree"
           uri
           (string-append
            "This a nonfree license.  Check the URI for details.  "
            comment)))

(define (linux-url version)
  "Return a URL for Linux VERSION."
  (string-append "mirror://kernel.org"
                       "/linux/kernel/v" (version-major version) ".x"
                       "/linux-" version ".tar.xz"))

;;; If you are corrupting the kernel on your own, consider using output of
;;; this procedure as a base for your options:
;;;   (corrupt-linux linux-libre-lts
;;;                  #:configs (cons* "CONFIG_FOO=y"
;;;                                   (nonguix-extra-linux-options linux-libre-lts)
(define-public (nonguix-extra-linux-options linux-or-version)
  "Return a list containing additional options that nonguix sets by default
for a corrupted linux package of specified version.  linux-or-version can be
some freedo package or an output of package-version procedure."
  (define linux-version
    (if (package? linux-or-version)
        (package-version linux-or-version)
        linux-or-version))

  (reverse (fold (lambda (opt opts)
                   (if (version>=? linux-version (car opt))
                       (cons* (cdr opt) opts)
                       opts))
                 '()
                 ;; List of additional options for nonguix corrupted linux.
                 ;; Each member is a pair of a minimal version (>=) and the
                 ;; option itself.  Option has to be in a format suitable for
                 ;; (@ (guix build kconfig) modify-defconfig) procedure.
                 ;;
                 ;; Do note that this list is intended for enabling use of
                 ;; hardware requiring non-free firmware.  If a configuration
                 ;; option does work under linux-libre, it should go into Guix
                 ;; actual.
                 '(
                   ;; Driver for MediaTek mt7921e wireless chipset
                   ("5.15" . "CONFIG_MT7921E=m")))))

(define* (corrupt-linux freedo
                        #:key
                        (name "linux")
                        (configs (nonguix-extra-linux-options freedo))
                        (defconfig #f))

  ;; TODO: This very directly depends on guix internals.
  ;; Throw it all out when we manage kernel hashes.
  (define gexp-inputs (@@ (guix gexp) gexp-inputs))

  (define extract-gexp-inputs
    (compose gexp-inputs force origin-uri))

  (define (find-source-hash sources url)
    (let ((versioned-origin
           (find (lambda (source)
                   (let ((uri (origin-uri source)))
                     (and (string? uri) (string=? uri url)))) sources)))
      (if versioned-origin
          (origin-hash versioned-origin)
          #f)))

  (let* ((version (package-version freedo))
         (url (linux-url version))
         (pristine-source (package-source freedo))
         (inputs (map gexp-input-thing (extract-gexp-inputs pristine-source)))
         (sources (filter origin? inputs))
         (hash (find-source-hash sources url)))
    (package
      (inherit
       (customize-linux
        #:name name
        #:source (origin
                   (method url-fetch)
                   (uri url)
                   (hash hash))
        #:configs configs
        #:defconfig defconfig))
      (version version)
      (home-page "https://www.kernel.org/")
      (synopsis "Linux kernel with nonfree binary blobs included")
      (description
       "The unmodified Linux kernel, including nonfree blobs, for running Guix System
on hardware which requires nonfree software to function."))))

(define-public linux-6.7
  (corrupt-linux linux-libre-6.7))




(define-public linux-firmware
  (package
    (name "linux-firmware")
    (version "20240115")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kernel.org/linux/kernel/firmware/"
                                  "linux-firmware-" version ".tar.xz"))
              (sha256
               (base32
                "13b75kd075famc58pvx4r9268pxn69nyihx7p3i6i7mvkgqayz5b"))))
    (build-system gnu-build-system)
    (arguments
     `(#:tests? #f
       #:make-flags (list (string-append "DESTDIR=" (assoc-ref %outputs "out")))
       #:phases
       (modify-phases %standard-phases
         (replace 'install
           (lambda* (#:key (make-flags '()) #:allow-other-keys)
             (apply invoke "make" "install-nodedup" make-flags)))
         (delete 'validate-runpath))))
    (home-page
     "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
    (synopsis "Nonfree firmware blobs for Linux")
    (description "Nonfree firmware blobs for enabling support for various
hardware in the Linux kernel.  This is a large package which may be overkill
if your hardware is supported by one of the smaller firmware packages.")
    (license
     (nonfree
      (string-append "https://git.kernel.org/pub/scm/linux/kernel/git/"
                     "firmware/linux-firmware.git/plain/WHENCE")))))

(define (select-firmware keep)
  "Modify linux-firmware copy list to retain only files matching KEEP regex."
  `(lambda _
     (use-modules (ice-9 regex))
     (substitute* "WHENCE"
       (("^(File|Link): *([^ ]*)(.*)" _ type file rest)
        (string-append (if (string-match ,keep file) type "Skip") ": " file rest)))))

(define-public amdgpu-firmware
  (package
    (inherit linux-firmware)
    (name "amdgpu-firmware")
    (arguments
     `(#:license-file-regexp "LICENSE.amdgpu"
       ,@(substitute-keyword-arguments (package-arguments linux-firmware)
           ((#:phases phases)
            `(modify-phases ,phases
               (add-after 'unpack 'select-firmware
                 ,(select-firmware "^amdgpu/")))))))
    (home-page "http://support.amd.com/en-us/download/linux")
    (synopsis "Nonfree firmware for AMD graphics chips")
    (description "Nonfree firmware for AMD graphics chips.  While most AMD
graphics cards can be run with the free Mesa, many modern cards require a
nonfree kernel module to run properly and support features like hibernation and
advanced 3D.")
    (license
     (nonfree
      (string-append
       "https://git.kernel.org/pub/scm/linux/kernel/git/firmware"
       "/linux-firmware.git/plain/LICENSE.amdgpu")))))


(operating-system
  (kernel linux-6.7)
  (firmware (list amdgpu-firmware))
  (locale "en_US.utf8")
  (timezone "Asia/Shanghai")
  (keyboard-layout (keyboard-layout "us"))
  (host-name "guix")

  ;; The list of user accounts ('root' is implicit).
  (users (cons* (user-account
                  (name "pillow")
                  (comment "pillow")
                  (group "users")
                  (home-directory "/home/pillow")
                  (supplementary-groups '("wheel" "netdev" "audio" "video")))
                %base-user-accounts))

  ;; Packages installed system-wide.  Users can also install packages
  ;; under their own account: use 'guix search KEYWORD' to search
  ;; for packages and 'guix install PACKAGE' to install a package.
  (packages (append (list (specification->package "nss-certs") sway)
                    %base-packages))

  ;; Below is the list of system services.  To search for available
  ;; services, run 'guix system search KEYWORD' in a terminal.
  (services (cons* (service sddm-service-type)
	      (modify-services %desktop-services
			       (delete gdm-service-type)
			     (guix-service-type
			       config => (guix-configuration
					   (inherit config)
					   (http-proxy "http://127.0.0.1:7890"))))))

  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (targets (list "/boot/efi"))
                (keyboard-layout keyboard-layout)))
  (initrd-modules (append '("mptspi") %base-initrd-modules))
  (swap-devices (list (swap-space
                        (target (uuid
                                 "a4fabc9f-3857-48cd-bb89-89ffb9eac147")))))

  ;; The list of file systems that get "mounted".  The unique
  ;; file system identifiers there ("UUIDs") can be obtained
  ;; by running 'blkid' in a terminal.
  (file-systems (cons* (file-system
                         (mount-point "/boot/efi")
                         (device (uuid "1149-8011"
                                       'fat32))
                         (type "vfat"))
                       (file-system
                         (mount-point "/")
                         (device (uuid
                                  "1a2aa3cc-6eb4-4d6a-a12f-2751f8d5a390"
                                  'ext4))
                         (type "ext4")) %base-file-systems)))
