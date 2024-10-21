obs = obslua

-- Global variables 
local source_name = ""  -- Name of the text source
local duration = 10      -- Duration of the timer in seconds
local delay = 5         -- Time in seconds for the final message to stay active
local seconds_remaining = 0  -- Remaining seconds
local timer_active = false  -- Timer state
local final_message = ""  -- Final message
local show_timer = true  -- Show the timer?
local in_delay = false  -- Delay state

-- Function to update the text of the source
local function update_text_source()
    if source_name == "" then
        return
    end

    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        local text_to_show = ""

        -- Show the timer if show_timer is true
        if show_timer and not in_delay then
            -- Calculate the mm:ss format
            local minutes = math.floor(seconds_remaining / 60)
            local seconds = seconds_remaining % 60
            text_to_show = string.format("%02d:%02d", minutes, seconds)
        elseif seconds_remaining <= 0 then
            -- Show only the final message if the timer has expired and we are in delay
            text_to_show = final_message
        end

        -- Update the text of the source
        local settings = obs.obs_data_create()
        obs.obs_data_set_string(settings, "text", text_to_show)
        obs.obs_source_update(source, settings)
        obs.obs_data_release(settings)
        obs.obs_source_release(source)
    else
        print("Source not found: " .. source_name)  -- Debug message
    end
end

-- Callback function executed every second
local function callback_timer()
    if not timer_active then
        return
    end

    if in_delay then
        -- If we are in delay, decrease the delay time
        delay = delay - 1
        if delay <= 0 then
            -- Restart the timer after the delay
            seconds_remaining = duration
            in_delay = false
            delay = 5  -- Reset the delay
        end
    else
        seconds_remaining = seconds_remaining - 1

        if seconds_remaining < 0 then
            -- When the timer expires, show the final message and activate the delay
            in_delay = true
            update_text_source()  -- Update the text with the final message
        else
            update_text_source()  -- Update the text with the new time
        end
    end
end

-- Function to start the timer
local function start_timer()
    if not timer_active then
        timer_active = true
        seconds_remaining = duration
        obs.timer_add(callback_timer, 1000)  -- Adds the callback that is executed every second
        update_text_source()  -- Initialize the text
    end
end

-- Function to stop the timer
local function stop_timer()
    timer_active = false
    obs.timer_remove(callback_timer)  -- Remove the callback
    seconds_remaining = duration  -- Reset the timer
    update_text_source()  -- Reset the text to the initial duration
end

-- Function to get available GDI text sources
local function get_sources()
    local sources = {}
    local source_list = obs.obs_enum_sources()

    for _, source in ipairs(source_list) do
        local source_type = obs.obs_source_get_type(source)
        local source_name = obs.obs_source_get_name(source)
        -- Filter only GDI text sources
        if source_type == obs.OBS_SOURCE_TYPE_TEXT_GDI then
            table.insert(sources, source_name)
        end
    end

    obs.source_list_release(source_list)
    return sources
end

-- Function to create the script's user interface
function script_properties()
    local props = obs.obs_properties_create()
    
    -- Create a dropdown for GDI text sources
    local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(p, name, name)
            end
        end
    end
    obs.source_list_release(sources)

    obs.obs_properties_add_int(props, "duration", "Timer Duration (seconds)", 1, 3600, 1)  -- Added for duration
    obs.obs_properties_add_int(props, "delay_duration", "Delay for Final Message (seconds)", 1, 3600, 1)  -- Added for delay
    obs.obs_properties_add_bool(props, "show_timer", "Show Timer")  -- Added to show the timer
    obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)  -- Final message
    obs.obs_properties_add_button(props, "start_button", "Start Timer", start_timer)  -- Button to start the timer
    obs.obs_properties_add_button(props, "reset_button", "Stop Timer", stop_timer)  -- Button to stop the timer

    return props
end

-- Function that updates the script's settings
function script_update(settings)
    source_name = obs.obs_data_get_string(settings, "source")  -- Changed from "source_name" to "source"
    duration = obs.obs_data_get_int(settings, "duration")  -- Added setting for duration
    delay = obs.obs_data_get_int(settings, "delay_duration")  -- Added setting for delay
    show_timer = obs.obs_data_get_bool(settings, "show_timer")  -- Added setting to show the timer
    final_message = obs.obs_data_get_string(settings, "stop_text")  -- Added setting for the final message
end

-- Descriptive function for the script
function script_description()
    return "Display a timed message for your live stream; set it up as you wish."
end
