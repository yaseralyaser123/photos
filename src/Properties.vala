/* Copyright 2009-2010 Yorba Foundation
 *
 * This software is licensed under the GNU LGPL (version 2.1 or later).
 * See the COPYING file in this distribution. 
 */

private abstract class Properties : Gtk.Table {
    uint line_count = 0;

    public Properties() {
        row_spacing = 0;
        column_spacing = 6;
        set_homogeneous(false);
    }

    protected void add_line(string label_text, string info_text) {
        Gtk.Label label = new Gtk.Label("");
        Gtk.Label info = new Gtk.Label("");
        
        label.set_justify(Gtk.Justification.RIGHT);
        
        label.set_markup(GLib.Markup.printf_escaped("<span font_weight=\"bold\">%s</span>", label_text));
        info.set_markup(is_string_empty(info_text) ? "" : info_text);
        
        label.set_alignment(1, (float) 5e-1);
        info.set_alignment(0, (float) 5e-1);
        
        info.set_ellipsize(Pango.EllipsizeMode.END);
        info.set_selectable(true);
        
        attach(label, 0, 1, line_count, line_count + 1, Gtk.AttachOptions.FILL, Gtk.AttachOptions.FILL, 0, 0);
        attach_defaults(info, 1, 2, line_count, line_count + 1);

        line_count++;
    }
    
    protected string get_prettyprint_time(Time time) {
        string timestring = time.format(_("%I:%M %p"));
        
        if (timestring[0] == '0')
            timestring = timestring.substring(1, -1);
        
        return timestring;
    }

    protected string get_prettyprint_date(Time date) {
        string date_string = null;
        Time today = Time.local(time_t());
        if (date.day_of_year == today.day_of_year && date.year == today.year) {
            date_string = _("Today");
        } else if (date.day_of_year == (today.day_of_year - 1) && date.year == today.year) {
            date_string = _("Yesterday");
        } else {
            date_string = format_local_date(date);
        }

        return date_string;
    }
    
    protected virtual void get_single_properties(DataView view) {
    }

    protected virtual void get_multiple_properties(Gee.Iterable<DataView>? iter) {
    }

    protected virtual void get_properties(Page current_page) {
        ViewCollection view = current_page.get_view();
        if (view == null)
            return;

        // summarize selected items, if none selected, summarize all
        int count = view.get_selected_count();
        Gee.Iterable<DataView> iter = null;
        if (count != 0) {
            iter = view.get_selected();
        } else {
            count = view.get_count();
            iter = (Gee.Iterable<DataView>) view.get_all();
        }
        
        if (iter == null || count == 0)
            return;

        if (count == 1) {
            foreach (DataView item in iter) {
                get_single_properties(item);
                break;
            }
        } else {
            get_multiple_properties(iter);
        }
    }

    protected virtual void clear_properties() {
        foreach (Gtk.Widget child in get_children())
            remove(child);
        
        line_count = 0;
    }

    public void update_properties(Page page) {
        clear_properties();
        internal_update_properties(page);
        show_all();
    }

    public virtual void internal_update_properties(Page page) {
        get_properties(page);
    }
    
    public void unselect_text() {
        foreach (Gtk.Widget child in get_children()) {
            if (child is Gtk.Label)
                ((Gtk.Label) child).select_region(0, 0);
        }
    }
}

private class BasicProperties : Properties {
    private string title;
    private time_t start_time = time_t();
    private time_t end_time = time_t();
    private Dimensions dimensions;
    private int photo_count;
    private int event_count;
    private string exposure;
    private string aperture;
    private string iso;

    public BasicProperties() {
    }

    private override void clear_properties() {
        base.clear_properties();
        title = "";
        start_time = 0;
        end_time = 0;
        dimensions = Dimensions(0,0);
        photo_count = -1;
        event_count = -1;
        exposure = "";
        aperture = "";
        iso = "";
    }

    private override void get_single_properties(DataView view) {
        base.get_single_properties(view);

        DataSource source = view.get_source();

        title = source.get_name();
        
        if (source is PhotoSource) {
            PhotoSource photo_source = (PhotoSource) source;
            
            start_time = photo_source.get_exposure_time();
            end_time = start_time;
            
            dimensions = photo_source.get_dimensions();
            
            PhotoMetadata? metadata = photo_source.get_metadata();
            if (metadata != null) {
                exposure = metadata.get_exposure_string();
                if (exposure == null)
                    exposure = "";
                
                aperture = metadata.get_aperture_string(true);
                if (aperture == null)
                    aperture = "";
                
                iso = metadata.get_iso_string();
                if (iso == null)
                    iso = "";
            }
        } else if (source is EventSource) {
            EventSource event_source = (EventSource) source;

            start_time = event_source.get_start_time();
            end_time = event_source.get_end_time();

            photo_count = event_source.get_photo_count();
        }
    }

    private override void get_multiple_properties(Gee.Iterable<DataView>? iter) {
        base.get_multiple_properties(iter);

        photo_count = 0;
        foreach (DataView view in iter) {
            DataSource source = view.get_source();
            
            if (source is PhotoSource) {
                PhotoSource photo_source = (PhotoSource) source;
                    
                time_t exposure_time = photo_source.get_exposure_time();

                if (exposure_time != 0) {
                    if (start_time == 0 || exposure_time < start_time)
                        start_time = exposure_time;

                    if (end_time == 0 || exposure_time > end_time)
                        end_time = exposure_time;
                }
                
                photo_count++;
            } else if (source is EventSource) {
                EventSource event_source = (EventSource) source;
          
                if (event_count == -1)
                    event_count = 0;

                if ((start_time == 0 || event_source.get_start_time() < start_time) &&
                    event_source.get_start_time() != 0 ) {
                    start_time = event_source.get_start_time();
                }
                if ((end_time == 0 || event_source.get_end_time() > end_time) &&
                    event_source.get_end_time() != 0 ) {
                    end_time = event_source.get_end_time();
                } else if (end_time == 0 || event_source.get_start_time() > end_time) {
                    end_time = event_source.get_start_time();
                }

                photo_count += event_source.get_photo_count();
                event_count++;
            }
        }
    }

    private override void get_properties(Page current_page) {
        base.get_properties(current_page);

        if (end_time == 0)
            end_time = start_time;
        if (start_time == 0)
            start_time = end_time;
    }

    private override void internal_update_properties(Page page) {
        base.internal_update_properties(page);

        // display the title if a Tag page
        if (title == "" && page is TagPage)
            title = ((TagPage) page).get_tag().get_name();
            
        if (title != "")
            add_line(_("Title:"), guarded_markup_escape_text(title));

        if (photo_count >= 0) {
            string label = _("Items:");
  
            if (event_count >= 0) {
                string event_num_string = (ngettext("%d Event", "%d Events", event_count)).printf(
                    event_count);

                add_line(label, event_num_string);
                label = "";
            }

            string photo_num_string = (ngettext("%d Photo", "%d Photos", photo_count)).printf(
                photo_count);

            add_line(label, photo_num_string);
        }

        if (start_time != 0) {
            string start_date = get_prettyprint_date(Time.local(start_time));
            string start_time = get_prettyprint_time(Time.local(start_time));
            string end_date = get_prettyprint_date(Time.local(end_time));
            string end_time = get_prettyprint_time(Time.local(end_time));

            if (start_date == end_date) {
                // display only one date if start and end are the same
                add_line(_("Date:"), start_date);

                if (start_time == end_time) {
                    // display only one time if start and end are the same
                    add_line(_("Time:"), start_time);
                } else {
                    // display time range
                    add_line(_("From:"), start_time);
                    add_line(_("To:"), end_time);
                }
            } else {
                // display date range
                add_line(_("From:"), start_date);
                add_line(_("To:"), end_date);
            }
        }

        if (dimensions.has_area()) {
            string label = _("Size:");

            if (dimensions.has_area()) {
                add_line(label, "%d &#215; %d".printf(dimensions.width, dimensions.height));
                label = "";
            }
        }

        if (exposure != "" || aperture != "" || iso != "") {
            string line = null;
            
            // attempt to put exposure and aperture on the same line
            if (exposure != "")
                line = exposure;
            
            if (aperture != "") {
                if (line != null)
                    line += ", " + aperture;
                else
                    line = aperture;
            }
            
            // if not both available but ISO is, add it to the first line
            if ((exposure == "" || aperture == "") && iso != "") {
                if (line != null)
                    line += ", " + "ISO " + iso;
                else
                    line = "ISO " + iso;
                
                add_line(_("Exposure:"), line);
            } else {
                // fit both on the top line, emit and move on
                if (line != null)
                    add_line(_("Exposure:"), line);
                
                // emit ISO on a second unadorned line
                if (iso != "") {
                    if (line != null)
                        add_line("","ISO " + iso);
                    else
                        add_line(_("Exposure:"), "ISO " + iso);
                }
            }
        }
    }
}

private class ExtendedPropertiesWindow : Gtk.Window {
    private ExtendedProperties properties = null;
    private const int FRAME_BORDER = 6;

    private class ExtendedProperties : Properties {
        private const string NO_VALUE = "";
        private string file_path;
        private uint64 filesize;
        private Dimensions? original_dim;
        private string camera_make;
        private string camera_model;
        private string flash;
        private string focal_length;
        private double gps_lat;
        private string gps_lat_ref;
        private double gps_long;
        private string gps_long_ref;
        private double gps_alt;
        private string artist;
        private string copyright;
        private string software;
        private string exposure_bias;
            
        protected override void clear_properties() {
            base.clear_properties();

            file_path = "";
            filesize = 0;
            original_dim = Dimensions(0, 0);
            camera_make = "";
            camera_model = "";
            flash = "";
            focal_length = "";
            gps_lat = -1;
            gps_lat_ref = "";
            gps_long = -1;
            gps_long_ref = "";
            artist = "";
            copyright = "";
            software = "";
            exposure_bias = "";
        }

        protected override void get_single_properties(DataView view) {
            base.get_single_properties(view);
            
            PhotoSource photo = view.get_source() as PhotoSource;
            if (photo == null)
                return;
            
            if (photo is TransformablePhoto)
                file_path = ((TransformablePhoto) photo).get_file().get_path();
            
            filesize = photo.get_filesize();
            
            PhotoMetadata? metadata = photo.get_metadata();
            if (metadata == null)
                return;
            
            original_dim = metadata.get_pixel_dimensions();
            camera_make = metadata.get_camera_make();
            camera_model = metadata.get_camera_model();
            flash = metadata.get_flash_string();
            focal_length = metadata.get_focal_length_string();
            metadata.get_gps(out gps_long, out gps_long_ref, out gps_lat, out gps_lat_ref, out gps_alt);
            artist = metadata.get_artist();
            copyright = metadata.get_copyright();
            software = metadata.get_software();
            exposure_bias = metadata.get_exposure_bias();
        }
        
        public override void internal_update_properties(Page page) {
            base.internal_update_properties(page);

            add_line(_("Location:"), (file_path != "" && file_path != null) ? file_path : NO_VALUE);

            add_line(_("File size:"), (filesize > 0) ? 
                format_size_for_display((int64) filesize) : NO_VALUE);

            add_line(_("Original dimensions:"), (original_dim != null && original_dim.has_area()) ?
                "%d &#215; %d".printf(original_dim.width, original_dim.height) : NO_VALUE);

            add_line(_("Camera make:"), (camera_make != "" && camera_make != null) ?
                camera_make : NO_VALUE);

            add_line(_("Camera model:"), (camera_model != "" && camera_model != null) ?
                camera_model : NO_VALUE);

            add_line(_("Flash:"), (flash != "" && flash != null) ? flash : NO_VALUE);

            add_line(_("Focal length:"), (focal_length != "" && focal_length != null) ?
                focal_length : NO_VALUE);

            add_line(_("Exposure bias:"), (exposure_bias != "" && exposure_bias != null) ? exposure_bias : NO_VALUE);
            
            add_line(_("GPS latitude:"), (gps_lat != -1 && gps_lat_ref != "" && 
                gps_lat_ref != null) ? "%f °%s".printf(gps_lat, gps_lat_ref) : NO_VALUE);
            
            add_line(_("GPS longitude:"), (gps_long != -1 && gps_long_ref != "" && 
                gps_long_ref != null) ? "%f °%s".printf(gps_long, gps_long_ref) : NO_VALUE);

            add_line(_("Artist:"), (artist != "" && artist != null) ? artist : NO_VALUE);

            add_line(_("Copyright:"), (copyright != "" && copyright != null) ? copyright : NO_VALUE);
    
            add_line(_("Software:"), (software != "" && software != null) ? software : NO_VALUE);
        }
    }

    public ExtendedPropertiesWindow(Gtk.Window owner) {
        add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.KEY_PRESS_MASK);
        focus_on_map = true;
        set_accept_focus(true);
        set_flags(Gtk.WidgetFlags.CAN_FOCUS);
        set_title(_("Extended Information"));
        set_size_request(300,-1);
        set_default_size(520, -1);
        set_position(Gtk.WindowPosition.CENTER);
        set_transient_for(owner);
        set_type_hint(Gdk.WindowTypeHint.DIALOG);

        delete_event.connect(hide_on_delete);

        properties = new ExtendedProperties();
        Gtk.Alignment alignment = new Gtk.Alignment(0.5f,0.5f,1,1);
        alignment.add(properties);
        alignment.set_padding(4, 4, 4, 4);
        add(alignment);
    }

    private override bool button_press_event(Gdk.EventButton event) {
        // LMB only
        if (event.button != 1)
            return (base.button_press_event != null) ? base.button_press_event(event) : true;
        
        begin_move_drag((int) event.button, (int) event.x_root, (int) event.y_root, event.time);
        
        return true;
    }

    private override bool key_press_event(Gdk.EventKey event) {
        // send through to AppWindow
        return AppWindow.get_instance().key_press_event(event);
    }

    public void update_properties(Page page) {
        properties.update_properties(page);
    }
    
    public override void show_all() {
        base.show_all();
        properties.unselect_text();
        grab_focus();
    }
}
