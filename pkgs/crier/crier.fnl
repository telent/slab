(local lgi (require :lgi))
(local dbus (require :dbus_proxy))
(local Gio lgi.Gio)
(local GLib lgi.GLib)
(local GV lgi.GLib.Variant)
(local GtkLayerShell lgi.GtkLayerShell)
(local variant dbus.variant)
(local Gtk lgi.Gtk)

(local inspect (require :inspect))

(local dbus-service-attrs
       {
        :bus dbus.Bus.SESSION
        :name "org.freedesktop.Notifications"
        :interface "org.freedesktop.Notifications"
        :path "/org/freedesktop/Notifications"
        })

(local bus (dbus.Proxy:new
            {
             :bus dbus.Bus.SESSION
             :name "org.freedesktop.DBus"
             :interface "org.freedesktop.DBus"
             :path "/org/freedesktop/DBus"
             }))


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
    (error "already running")))

(let [css (: (io.open "styles.css") :read "*a")
      style_provider (Gtk.CssProvider)]
  (style_provider:load_from_data css)
  (Gtk.StyleContext.add_provider_for_screen
   (lgi.Gdk.Screen.get_default)
   style_provider
   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
   ))

;; for each open message there is a widget
;; when a message is closed, we need to find its widget
;; and remove it from the container
;; if there are no messages left, hide the windox

(fn make-window []
  (let [window (Gtk.Window {:on_destroy Gtk.main_quit})
        box (Gtk.Box {
                      :orientation Gtk.Orientation.VERTICAL
                      })]
    (window:add box)
    (when true
      (GtkLayerShell.init_for_window window)
      (GtkLayerShell.set_layer window GtkLayerShell.Layer.TOP)
      (GtkLayerShell.auto_exclusive_zone_enable window)

      (GtkLayerShell.set_margin window GtkLayerShell.Edge.TOP 1)
      (GtkLayerShell.set_margin window GtkLayerShell.Edge.BOTTOM 10)

      (GtkLayerShell.set_anchor window GtkLayerShell.Edge.TOP 1)
      (GtkLayerShell.set_anchor window GtkLayerShell.Edge.LEFT 1)
      (GtkLayerShell.set_anchor window GtkLayerShell.Edge.RIGHT 1))
    (window:hide)
    {:window window :box box}))

(local window (make-window))

(local notifications {})

(fn update-window []
  (each [id widget (pairs notifications)]
    (if (not (widget.widget:get_parent))
        (window.box:pack_start widget.widget false false 5)))
  (if (next notifications)
      (window.window:show_all)
      (window.window:hide)))

(var notification-id 10)
(fn next-notification-id []
  (set notification-id  (+ notification-id 1))
  notification-id)

(fn delete-notification [id]
  (let [widget (. notifications id)]
    (tset notifications id nil)
    (window.box:remove widget.widget)
    (update-window)
    false
    ))

(fn update-notification-widget [widget noti]
  (doto widget
    (: :set-summary noti.summary)
    (: :set-body noti.body)
    (: :set-icon noti.app-icon)))

(fn make-notification-widget [id]
  (let [summary (Gtk.Label { :name "summary" })
        body (Gtk.Label)
        icon  (Gtk.Image)
        cancel-me (fn [] (delete-notification id))
        event-box (Gtk.EventBox {
                                 :on_button_press_event cancel-me
                                 })
        hbox (Gtk.Box {
                       :name "notification"
                       :orientation Gtk.Orientation.HORIZONTAL
                       })
        vbox (Gtk.Box { :orientation Gtk.Orientation.VERTICAL})]
    (vbox:pack_start summary false false 0)
    (vbox:pack_start body true false 0)
    (hbox:pack_start icon false false 0)
    (hbox:pack_start vbox true true 0)
    (event-box:add hbox)
    {
     :set-summary (fn [self value]
                    (set summary.label value))
     :set-body (fn [self value]
                 (set body.label value))
     :set-icon (fn [self value]
                 (when value
                   (icon:set_from_icon_name
                    value
                    Gtk.IconSize.DND
                    )))
     :widget event-box
     }))

(fn timeout-ms [noti]
  (if (or (not noti.timeout) (= noti.timeout -1))
      5000
      (> noti.timeout 0)
      noti.timeout
      (= noti.timeout 0)
      nil))

(fn add-notification [noti]
  (let [id (if (= noti.id 0) (next-notification-id) noti.id)
        widget (or (. notifications id) (make-notification-widget id))
        timeout (timeout-ms noti)]
    (when timeout
      (lgi.GLib.timeout_add
       lgi.GLib.PRIORITY_DEFAULT timeout  #(delete-notification id)))

    (update-notification-widget widget noti)
    (tset notifications id widget)
    (update-window)
    id))

(fn make-notification [params]
  {
   :sender (. params 1)
   :id (. params 2)
   :app-icon (. params 3)
   :summary (. params 4)
   :body (. params 5)
   :actions (. params 6)
   :hints (. params 7)
   :timeout (. params 8)
   })

(fn handle-dbus-method-call [conn sender path interface method params invocation]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface))
    (match method
      "GetCapabilities"
      (invocation:return_value (GV "as" ["actions"]))

      "GetServerInformation"
      (invocation:return_value
       (GV "(ssss)" ["crier"
                     "telent"
                     "0.1"
                     "1.2"]))

      "Notify"
      (let [p (dbus.variant.strip params)
            n (make-notification p)]
        (invocation:return_value (GV "(u)"
                                     [(add-notification n)])))
      )))

(fn handle-dbus-get [conn sender path interface name]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface)
             (= name "Visible"))
    (lgi.GLib.Variant "b" true)))

(local interface-info
       (let [xml (: (io.open "interface.xml" "r") :read "*a")
             node-info (Gio.DBusNodeInfo.new_for_xml xml)]
         (. node-info.interfaces 1)))

(Gio.DBusConnection.register_object
 bus.connection
 dbus-service-attrs.path
 interface-info
 (lgi.GObject.Closure handle-dbus-method-call)
 (lgi.GObject.Closure handle-dbus-get)
 (lgi.GObject.Closure (fn [a] (print "set"))))

(Gtk:main)
