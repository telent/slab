(local lgi (require :lgi))
(local Gio lgi.Gio)
(local dbus (require :dbus_proxy))
(local inspect (require :inspect))

(local dbus-service-attrs
       {
        :bus dbus.Bus.SESSION
        :name "net.telent.saturn"
        :interface "net.telent.saturn"
        :path "/net/telent/saturn"
        })

(local bus (dbus.Proxy:new
            {
             :bus dbus.Bus.SESSION
             :name "org.freedesktop.DBus"
             :interface "org.freedesktop.DBus"
             :path "/org/freedesktop/DBus"
             }))

(local interface-info
       (let [xml
             "<node>
                <interface name='net.telent.saturn'>
                  <method name='SetVisible'>
                    <arg type='b' name='visible' direction='in'/>
                    <doc:doc><doc:description>
                      Switch visibility of launcher window
                    </doc:description></doc:doc>
                  </method>
                  <method name='ToggleVisible'>
                    <doc:doc><doc:description>
                      Toggle launcher window visible/invisible
                    </doc:description></doc:doc>
                  </method>
                  <property name='Visible' type='b' access='read'>
                  </property>
                </interface>
              </node>"
             node-info (Gio.DBusNodeInfo.new_for_xml xml)]
         (. node-info.interfaces 1)))

;; these values don't seem to be available through introspection
(local DBUS_NAME_FLAG_DO_NOT_QUEUE 4)
(local DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER 1)
(local DBUS_REQUEST_NAME_REPLY_IN_QUEUE 2)
(local DBUS_REQUEST_NAME_REPLY_EXISTS 3)
(local DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER 4)

(let [ret (bus:RequestName dbus-service-attrs.name
                           DBUS_NAME_FLAG_DO_NOT_QUEUE)]
  (match ret
    DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER
    true

    DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER
    true

    DBUS_REQUEST_NAME_REPLY_IN_QUEUE
    (error "unexpected DBUS_REQUEST_NAME_REPLY_IN_QUEUE")

    DBUS_REQUEST_NAME_REPLY_EXISTS
    ;; Show the currently running instance
    (let [saturn (dbus.Proxy:new dbus-service-attrs)]
      (saturn:SetVisible true)
      (os.exit 0))))


(local lfs (require :lfs))
(local inifile (require :inifile))
(local inspect (require :inspect))
(local posix (require :posix))

(local Gtk lgi.Gtk)
(local Pango lgi.Pango)

(local icon-theme (Gtk.IconTheme.get_default))

(local window (Gtk.Window {
                           :title "Saturn V"
                           :default_width 720
                           :default_height 800
                           :on_destroy Gtk.main_quit
                           }))
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
    (when vals.Icon
      (tset vals "IconImage" (find-icon vals.Icon)))
    vals))

(fn all-apps []
  (var apps-table {})
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
;; in which the launcher is supposed to interpolate filenames/urls etc.
;; We don't afford the user any way to pick filenames, but we do need
;; to remove the placeholders.
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
  ;; FIXME check app.DBusActivatable and do DBus launch if true
  (let [cmd (parse-percents app.Exec)]
    (if app.Terminal
        (spawn-async ["kitty" cmd])
        (spawn-async ["sh" "-c" cmd]))
    (window:hide)))

(fn button-for [app]
  (doto (Gtk.Button
         {
          :label app.Name
          :image-position Gtk.PositionType.TOP
          :relief Gtk.ReliefStyle.NONE
          :on_clicked #(launch app)          })
    (: :set_image app.IconImage)))


(fn handle-dbus-method-call [conn sender path interface method params invocation]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface))
    (match method
      "SetVisible"
      (let [[value] (dbus.variant.strip params)]
        (if value (window:show_all) (window:hide))
        (invocation:return_value nil))
      "ToggleVisible"
      (let [v window.visible]
        (if v (window:hide) (window:show_all))
        (invocation:return_value nil)))))

(fn handle-dbus-get [conn sender path interface name]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface)
             (= name "Visible"))
    (lgi.GLib.Variant "b" window.visible)))

(Gio.DBusConnection.register_object
 bus.connection
 dbus-service-attrs.path
 interface-info
 (lgi.GObject.Closure handle-dbus-method-call)
 (lgi.GObject.Closure handle-dbus-get)
 (lgi.GObject.Closure (fn [a] (print "set"))))

(let [grid (Gtk.FlowBox {
                         :orientation Gtk.Orientation.HORIZONTAL
                         :valign Gtk.Align.START
                         :column_spacing 2
                         :row_spacing 5
                         })
      scrolled-window (Gtk.ScrolledWindow {})]
  (each [_ app (pairs (all-apps))]
    (grid:insert (button-for app) -1))
  (scrolled-window:add grid)
  (window:add scrolled-window))

(window:show_all)
(Gtk:main)
