(local {: Gio
        : GLib
        : GObject
        : Gtk
        : GdkPixbuf
        : Gdk
        : Pango}
       (require :lgi))

(local {: List
        : stringx
        : tablex
        }
       ((require :pl.import_into)))

(local dbus (require :dbus_proxy))
(local inspect (require :inspect))
(local lfs (require :lfs))
(local inifile (require :inifile))
(local posix (require :posix))

(local ICON_SIZE 64)

(local CSS "
    * {
      color: rgb(255, 255, 255);
      text-shadow:
           0px  1px rgba(0, 0, 0, 255)
        ,  1px  0px rgba(0, 0, 0, 255)
        ,  0px -1px rgba(0, 0, 0, 255)
        , -1px  0px rgba(0, 0, 0, 255)
        ,  1px  1px rgba(0, 0, 0, 255)
        ,  1px -1px rgba(0, 0, 0, 255)
        , -1px  1px rgba(0, 0, 0, 255)
        , -1px -1px rgba(0, 0, 0, 255)
      ;
    }
    #toplevel {
      background-color: rgba(0, 0, 0, 0.6);
    }
  ")

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


(local path {
             :absolute? (fn [str] (= (str:sub 1 1) "/"))
             :concat (fn [...] (table.concat [...] "/"))
             })
(local search-path {
                    :concat (fn [...] (table.concat [...] ":"))
                    })


(local icon-theme (Gtk.IconTheme.get_default))

;; Use the declared CSS for this app
(let [style_provider (Gtk.CssProvider)]
  (style_provider:load_from_data CSS)
  (Gtk.StyleContext.add_provider_for_screen
    (Gdk.Screen.get_default)
    style_provider
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    ))

(local window (Gtk.Window {
                           :title "Saturn V"
                           :name "toplevel"
                           :default_width 720
                           :default_height 800
                           :on_destroy Gtk.main_quit
                           }))

;; Using RGBA visual for semi-transparent backgrounds
;; Requires compositing (e.g. a compositor on X11)
(let [screen (window:get_screen)
      visual (screen:get_rgba_visual)]
  (window:set_visual visual))

(fn find-icon [name]
  (var found false)
  (if (path.absolute? name)
    ;; From a direct path
    (set found (GdkPixbuf.Pixbuf.new_from_file_at_size name ICON_SIZE ICON_SIZE))
    ;; From icon theme
    (let [sizes (icon-theme:get_icon_sizes name)]
      ;; Uses a list of "safe fallback" values
      ;; Try the desired size first
      (each [_ res (pairs [ICON_SIZE 128 64 48]) :until found]
        (set found
             (-?> (icon-theme:load_icon
                   name res
                   (+ Gtk.IconLookupFlags.FORCE_SVG Gtk.IconLookupFlags.USE_BUILTIN))
                 (: :scale_simple ICON_SIZE ICON_SIZE GdkPixbuf.InterpType.BILINEAR))))
      ))
  (Gtk.Image.new_from_pixbuf found))

(fn read-desktop-file [f]
  (let [parsed (inifile.parse f)
        vals (. parsed "Desktop Entry")]
    (when vals.Icon
      (tset vals "IconImage" (find-icon vals.Icon)))
    (tset vals "ID" (f:sub 0 -9))
    vals))

(fn current-user-home []
  "Returns current user's home directory."
  (-> (posix.unistd.getuid)
      (posix.pwd.getpwuid)
      (. :pw_dir)))

(fn xdg-data-home []
  "Provides XDG_DATA_HOME or its default fallback value"
  (or (os.getenv "XDG_DATA_HOME")
      (path.concat (current-user-home) ".local/share/")))

(fn xdg-data-dirs []
  "Provides all data-dirs as a List. Most important first."
  ;; Expected to be used with gmatch as a generator.
  (let [dirs (List)]
  (dirs:append (xdg-data-home))
  (dirs:extend (stringx.split (os.getenv "XDG_DATA_DIRS") ":"))
  dirs
  ))

(fn all-apps []
  ;; Each desktop entry representing an application is identified
  ;; by its desktop file ID, which is based on its filename.
  ;;  — https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-latest.html#desktop-file-id
  "Provides apps in a List, sorted by name"
  (var apps-table {})
  ;; Reversing the data dirs gives priority to the first elements.
  ;; This means conflicting `.desktop` files (or: desktop file ID) are given
  ;; priority to the first elements by "simply" reading it last.
  (each [path (List.iter (List.reverse (xdg-data-dirs)))]
    (let [apps-dir (..  path "/applications/")]
      (when (lfs.attributes apps-dir)
        (each [f (lfs.dir apps-dir)]
          (when (= (f:sub -8) ".desktop")
            (let [attrs (read-desktop-file (.. apps-dir  f))]
              (when (not attrs.NoDisplay)
                (tset apps-table attrs.ID attrs))))))))
  ;; We have a table indexed by IDs, we don't care about the indexing.
  ;; Make a List and sort it by name.
  (List.sort (List (tablex.values apps-table))
    (fn [a b] (< (string.upper a.Name) (string.upper b.Name)))))

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
    (GLib.Variant "b" window.visible)))

(Gio.DBusConnection.register_object
 bus.connection
 dbus-service-attrs.path
 interface-info
 (GObject.Closure handle-dbus-method-call)
 (GObject.Closure handle-dbus-get)
 (GObject.Closure (fn [a] (print "set"))))

(let [grid (Gtk.FlowBox {
                         :orientation Gtk.Orientation.HORIZONTAL
                         :valign Gtk.Align.START
                         :column_spacing 2
                         :row_spacing 5
                         :homogeneous true
                         })
      scrolled-window (Gtk.ScrolledWindow {})]
  (each [app (List.iter (all-apps))]
    (grid:insert (button-for app) -1))
  (scrolled-window:add grid)
  (window:add scrolled-window))

(window:show_all)
(Gtk:main)
