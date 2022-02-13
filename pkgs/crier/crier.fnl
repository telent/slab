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

(local notifications {})

(fn update-window [window box]
  (each [id widget (pairs notifications)]
    (if (not (widget.widget:get_parent))
        (box:pack_start widget.widget false false 5)))
  (if (next notifications)
      (window:show_all)
      (window:hide)))

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
    {
     :update (fn [self] (update-window window box))
     :remove-child (fn [self child]
                     (box:remove child)
                     (update-window window box))
     }))

(local window (make-window))

(var notification-id 10)
(fn next-notification-id []
  (set notification-id  (+ notification-id 1))
  notification-id)

(fn delete-notification [id]
  (let [widget (. notifications id)]
    (if widget
        (do
          (tset notifications id nil)
          (window:remove-child widget.widget)
          true)
        (values nil "no notification with that id"))))

(fn update-notification-widget [widget params]
  (doto widget
    (: :set-summary params.summary)
    (: :set-body params.body)
    (: :set-icon params.app-icon)
    (: :set-buttons params.actions)))

(fn emit-action [id action]
  (bus.connection:emit_signal
   nil ; destination
   dbus-service-attrs.path
   dbus-service-attrs.interface
   "ActionInvoked"
   (GV "(us)" [id action])))

(fn action-button [id key label]
  (let [b (Gtk.Button {
                       :on_clicked
                       #(emit-action id key)
                       :label label })]
    (b.style_context:add_class "action_button")
    (set b.relief Gtk.ReliefStyle.NONE)
    b))

(fn make-notification-widget [id]
  (let [summary (Gtk.Label { :name "summary" })
        body (Gtk.Label)
        icon  (Gtk.Image)
        event-box (Gtk.EventBox {
                                 :on_button_press_event #(emit-action id "default")
                                 })
        messages (Gtk.Box { :orientation Gtk.Orientation.VERTICAL})
        icon-and-messages (Gtk.Box {

                       :orientation Gtk.Orientation.HORIZONTAL
                                    })
        buttons (Gtk.Box { :orientation Gtk.Orientation.HORIZONTAL})
        with-buttons (Gtk.Box {
                               :name "notification"
                               :orientation Gtk.Orientation.VERTICAL})
        ]
    (messages:pack_start summary false false 0)
    (messages:pack_start body true false 0)
    (icon-and-messages:pack_start icon false false 0)
    (icon-and-messages:pack_start messages true true 0)
    (with-buttons:pack_start icon-and-messages false false 0)
    (with-buttons:pack_start buttons false false 5)
    (event-box:add with-buttons)
    {
     :set-summary (fn [self value]
                    (set summary.label value))
     :set-body (fn [self value]
                 (set body.label value))
     :set-buttons (fn [self actions]
                    (each [_ child (ipairs (buttons:get_children))]
                      (child:destroy))
                    (when actions
                      (each [key label (pairs actions)]
                        (if (not (= key "default"))
                            (buttons:pack_end
                             (action-button id key label)
                             false false 5)))))
     :set-icon (fn [self value]
                 (when value
                   (icon:set_from_icon_name
                    value
                    Gtk.IconSize.DND
                    )))
     :widget event-box
     }))

(fn timeout-ms [params]
  (if (or (not params.timeout) (= params.timeout -1))
      5000
      (> params.timeout 0)
      params.timeout
      (= params.timeout 0)
      nil))

(fn add-notification [params]
  (let [id (if (= params.id 0) (next-notification-id) params.id)
        widget (or (. notifications id) (make-notification-widget id))
        timeout (timeout-ms params)]
    (when timeout
      (lgi.GLib.timeout_add
       lgi.GLib.PRIORITY_DEFAULT timeout  #(do (delete-notification id) nil)))

    (update-notification-widget widget params)
    (tset notifications id widget)
    (window:update)
    id))

(fn parse-actions [list]
  (let [out {}]
    (for [i 1 (# list) 2]
      (tset out (. list i) (. list (+ 1 i))))
    out))

(fn params-from-args [sender id icon summary body actions hints timeout]
  {
   :sender sender
   :id id
   :app-icon icon
   :summary summary
   :body body
   :actions (parse-actions actions)
   :hints hints
   :timeout timeout
   })

(local interface-info
       (let [xml (: (io.open "interface.xml" "r") :read "*a")
             node-info (Gio.DBusNodeInfo.new_for_xml xml)]
         (. node-info.interfaces 1)))

(local dbus-methods
       {
        "GetCapabilities" #["actions" "body" "persistence"]
        "GetServerInformation" #(values "crier" "telent" "0.1" "1.2")
        "Notify" #(add-notification (params-from-args $...))
        "CloseNotification" (fn [id]
                              (let [(won err) (delete-notification id)]
                                (if won (values) (error err))))
        })

(fn args-signature [args]
  (var sig "")
  (each [_ v (ipairs args)]
    (set sig (.. sig v.signature)))
  sig)

(fn handle-dbus-method-call [conn sender path interface method params invocation]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface))
    (let [p (dbus.variant.strip params)
          info (interface-info:lookup_method method)
          sig (args-signature info.out_args)]
      (match (table.pack (pcall (. dbus-methods method) (table.unpack p)))
        [true & vals]
        (invocation:return_value (GV (.. "(" sig ")") vals))
        _
        (invocation:return_value nil)))))

(fn handle-dbus-get [conn sender path interface name]
  (when (and (= path dbus-service-attrs.path)
             (= interface dbus-service-attrs.interface)
             (= name "Visible"))
    (lgi.GLib.Variant "b" true)))

(Gio.DBusConnection.register_object
 bus.connection
 dbus-service-attrs.path
 interface-info
 (lgi.GObject.Closure handle-dbus-method-call)
 (lgi.GObject.Closure handle-dbus-get)
 (lgi.GObject.Closure (fn [a] (print "set"))))


(add-notification {
                   :app-icon "dialog-information"
                   :body "This is an example notifiddcation."
                   :id 3
                   :sender "notify-send"
                   :summary "Hello world!"
                   })

(Gtk:main)
