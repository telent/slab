(local dbus (require :dbus_proxy))

(local bus (dbus.Proxy:new
            {
             :bus dbus.Bus.SESSION
             :name "org.freedesktop.DBus"
             :interface "org.freedesktop.DBus"
             :path "/org/freedesktop/DBus"
             }))

(local DBUS_NAME_FLAG_DO_NOT_QUEUE 4)
(let [ret (bus:RequestName "net.telent.saturn" DBUS_NAME_FLAG_DO_NOT_QUEUE)]
  (if (or (= ret 1) (= ret 4))
      true
      (= ret 2)
      (error "unexpected DBUS_REQUEST_NAME_REPLY_IN_QUEUE")
      (= ret 3)
      (do
        (print "already running")
        (os.exit 0))))

;; https://vwangsf.medium.com/creating-a-d-bus-service-with-dbus-python-and-polkit-authentication-4acc9bc5ed29

(local lfs (require :lfs))
(local inifile (require :inifile))
(local inspect (require :inspect))
(local posix (require :posix))

(local lgi (require :lgi))
(local Gtk lgi.Gtk)
(local Pango lgi.Pango)

(local icon-theme (Gtk.IconTheme.get_default))

(fn find-icon [name]
  (var found false)
  (if (= (name.sub 1 1) "/")
      (Gtk.Image.new_from_file name)
      (let [sizes (icon-theme:get_icon_sizes name)]

        (each [_ res (pairs [64 48]) :until found]
          (set found (icon-theme:load_icon
                      name res
                      (+ Gtk.IconLookupFlags.FORCE_SVG Gtk.IconLookupFlags.USE_BUILTIN))))
        (Gtk.Image.new_from_pixbuf found))))

(fn read-desktop-file [f]
  (let [parsed (inifile.parse f)
        vals (. parsed "Desktop Entry")]
    (when vals.Icon (tset vals "IconImage" (find-icon vals.Icon)))
    vals))

(fn all-apps []
  (var apps-table {})
  ;; for i in ${XDG_DATA_DIRS//:/ /} ; do ls $i/applications/*.desktop ;done
  (each [path (string.gmatch (os.getenv "XDG_DATA_DIRS") "[^:]*")]
    (let [apps  (..  path "/applications/")]
      (when (lfs.attributes apps)
        (each [f (lfs.dir apps)]
          (when (= (f:sub -8) ".desktop")
            (let [attrs (read-desktop-file (.. apps  f))]
              (when (not attrs.NoDisplay)
                (tset apps-table attrs.Name attrs))))))))
  apps-table)

;; Exec entries in desktop files may contain %u %f and other characters
;; in which the launcheris supposed to interpolate filenames/urls etc.
;; We don't
(fn parse-percents [str]
  (str:gsub "%%(.)" (fn [c] (if (= c "%") "%" ""))))

(fn spawn-async [vec]
  (let [pid (posix.unistd.fork)]
    (if (> pid 0) true
        (< pid 0) (assert (= "can't fork" nil))
        (do
          (for [f 3 255] (posix.unistd.close f))
          (posix.execp "/usr/bin/env" vec)))))

(fn launch [app]
;  (print (if app.DBusActivatable "dbus" "not dbus"))
  (let [cmd (parse-percents app.Exec)]
    (if app.Terminal
        (spawn-async ["kitty" cmd])
        (spawn-async ["sh" "-c" cmd]))
    (Gtk.main_quit)
    (os.exit 0)))

(fn button-for [app]
  (doto (Gtk.Button
         {
          :label app.Name
          :image-position Gtk.PositionType.TOP
          :relief Gtk.ReliefStyle.NONE
          :on_clicked #(launch app)          })
    (: :set_image app.IconImage)))

(let [grid (Gtk.Grid {
                      :column_spacing 5
                      :row_spacing 5
                      })
      scrolled-window (Gtk.ScrolledWindow {})
      window (Gtk.Window {
                          :title "Saturn V"
                          :default_width 720
                          :default_height 800
                          :on_destroy Gtk.main_quit
                          })]
  (var i 0)
  (each [_ app (pairs (all-apps))]
    (let [x (%  i 4)
          y (// i 4)]
      (set i (+ i 1))
      (grid:attach (button-for app) x y 1 1)))
  (scrolled-window:add grid)
  (window:add scrolled-window)
  (window:show_all))

(Gtk:main)
