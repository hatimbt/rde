(define-module (rde examples abcdw configs)
  #:use-module (rde features)
  #:use-module (rde features base)
  #:use-module (rde features gnupg)
  #:use-module (rde features keyboard)
  #:use-module (rde features system)
  #:use-module (rde features wm)
  #:use-module (rde features xdg)
  #:use-module (rde features password-utils)
  #:use-module (rde features version-control)
  #:use-module (rde features fontutils)
  #:use-module (rde features terminals)
  #:use-module (rde features tmux)
  #:use-module (rde features shells)
  #:use-module (rde features ssh)
  #:use-module (rde features emacs)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system mapped-devices)
  #:use-module (gnu packages)
  #:use-module (guix gexp)
  #:use-module (ice-9 match))


;;; User-specific features

;; Initial user's password hash will be available in store, so it's
;; use this feature with care
;; (display (crypt "hi" "$6$abc"))

(define %abcdw-features
  (list
   (feature-user-info
    #:user-name "bob"
    #:full-name "Andrew Tropin"
    #:email "andrew@trop.in")
   (feature-gnupg
    #:gpg-primary-key "74830A276C328EC2"
    #:gpg-smart-card? #t)
   (feature-password-store
    #:remote-password-store-url "ssh://abcdw@olorin.lan/~/state/password-store")
   (feature-keyboard
    #:keyboard-layout %dvorak-jcuken-layout)))

;;; TODO: feature-brightness, use brightnessctl, it support
;;; systemd/elogind api for unprevileged call.
;;; TODO: Make sway depend on feature-desktop-services
;;; TODO: feature-wallpapers https://wallhaven.cc/
;;; TODO: feature-battery
;; PipeWire/iwd:
;; https://github.com/krevedkokun/guix-config/blob/master/system/yggdrasil.scm


;;; Generic features should be applicable for various hosts/users/etc

(define* (pkgs #:rest lst)
  (map specification->package+output lst))

(define %main-features
  (list
   ;; (feature-pipewire)
   ;; (feature-blablabla)

   (feature-alacritty
    #:config-file
    (local-file "../../../stale/dotfiles/.config/alacritty/alacritty.yml"))
   (feature-tmux
    #:config-file
    (local-file "../../../stale/dotfiles/.tmux.conf" "tmux.conf"))
   (feature-zsh)

   (feature-ssh)
   (feature-git)

   (feature-fonts)

   (feature-desktop-services)
   (feature-sway
    #:config-file (local-file "../../sway/config"))
   (feature-sway-run-on-tty
    #:sway-tty-number 2)

   (feature-emacs
    #:additional-elisp-packages
    (pkgs "emacs-guix" "emacs-telega" "emacs-pdf-tools" "emacs-yasnippet"))
   (feature-emacs-org-mode)
   (feature-emacs-magit)
   (feature-emacs-faces)
   (feature-emacs-completion)
   (feature-emacs-org-roam
    #:org-roam-directory "~/work/notes/notes")

   (feature-base-services)
   (feature-xdg-base-directories)
   (feature-base-packages
    #:home-packages
    (pkgs
     "alsa-utils" "mpv" "youtube-dl"
     "obs" "obs-wlrobs"
     "ungoogled-chromium-wayland" "ublock-origin-chromium"
     "nyxt"
     "hicolor-icon-theme" "adwaita-icon-theme"
     "ripgrep" "curl" "make"))))

(define %laptop-features
  (list ))


;;; Hardware/host specifis features

;; TODO: Switch from UUIDs to partition labels For better
;; reproducibilty and easier setup.  Grub doesn't support luks2 yet.

(define ixy-mapped-devices
  (list (mapped-device
         (source (uuid "0e51ee1e-49ef-45c6-b0c3-6307e9980fa9"))
         (target "enc")
         (type luks-device-mapping))))

(define ixy-file-systems
  (append
   (map (match-lambda
	  ((subvol . mount-point)
	   (file-system
	     (type "btrfs")
	     (device "/dev/mapper/enc")
	     (mount-point mount-point)
	     (options (format #f "subvol=~a" subvol))
	     (dependencies ixy-mapped-devices))))
	'((root . "/")
	  (boot . "/boot")
	  (gnu  . "/gnu")
	  (home . "/home")
	  (data . "/data")
	  (log  . "/var/log")))
   (list
    (file-system
      (mount-point "/boot/efi")
      (type "vfat")
      (device (uuid "8C99-0704" 'fat32))))))

(define %ixy-features
  (list
   (feature-host-info
    #:host-name "ixy"
    #:timezone  "Europe/Moscow")
   ;;; Allows to declare specific bootloader configuration,
   ;;; grub-efi-bootloader used by default
   ;; (feature-bootloader)
   (feature-file-systems
    #:mapped-devices ixy-mapped-devices
    #:file-systems   ixy-file-systems)
   (feature-hidpi)))


;;; rde-config and helpers for generating home-environment and
;;; operating-system records.

(define-public ixy-config
  (rde-config
   (features
    (append
     %abcdw-features
     %main-features
     %ixy-features))))

;; TODISCUSS: Make rde-config-os/he to be a feature instead of getter?
(define ixy-os
  (rde-config-operating-system ixy-config))
(define ixy-he
  (rde-config-home-environment ixy-config))

(define (dispatcher)
  (let ((rde-target (getenv "RDE_TARGET")))
    (match rde-target
      ("ixy-home" ixy-he)
      ("ixy-system" ixy-os)
      (_ ixy-he))))

;; (pretty-print-rde-config ixy-config)
;; (use-modules (gnu services)
;; 	     (gnu services base))
;; (display
;;  (filter (lambda (x)
;; 	   (eq? (service-kind x) console-font-service-type))
;; 	 (rde-config-system-services ixy-config)))

;; (use-modules (rde features))
;; ((@@ (ice-9 pretty-print) pretty-print)
;;  (map feature-name (rde-config-features ixy-config)))

(dispatcher)