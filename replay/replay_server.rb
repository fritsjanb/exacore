require 'rubygems'
require 'patchbay'
require 'irb'
require 'json'
require 'thin'

require_relative 'replay_app'
require_relative '../input/shuttlepro'

app = Replay::ReplayApp.new
$app = app # hack

CLIP_BASE_PATH='/root/saved_clips'

def configure
    yield $app
end

load './replay_config.rb'

app.game_data.clock = "13:37"
app.start

module IRB # :nodoc:
    def self.start_session(binding)
        unless @__initialized
            args = ARGV
            ARGV.replace(ARGV.dup)
            IRB.setup(nil)
            ARGV.replace(args)
            @__initialized = true
        end

        workspace = WorkSpace.new(binding)

        irb = Irb.new(workspace)

        @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
        @CONF[:MAIN_CONTEXT] = irb.context

        catch(:IRB_EXIT) do
            irb.eval_input
        end
    end
end

class ReplayEvent
    attr_accessor :id
    attr_accessor :type
    attr_accessor :shots

    def make_json
        {
            "id" => @id,
            "type" => @type,
            "shots" => @shots.each_with_index.map { |shot, source_id| shot.make_json(source_id) }
        }
    end
end

class ReplayLocalControl < ShuttleProInput
    def initialize(app)
        @app = app
        @shifted = 0
        @current_event = @app.each_source.map { |src| nil }
        @current_preview_source = 0
        @event_id = 0
        @event_list = []
        @event_ptr = 0
        super()
    end

    attr_accessor :web_interface
    attr_accessor :current_event

    def on_shuttle(value)
        case value
        when -6
            @app.program.set_speed(1,8)
        when -5
            @app.program.set_speed(1,6)
        when -4
            @app.program.set_speed(1,4)
        when -3
            @app.program.set_speed(1,3)
        when -2
            @app.program.set_speed(3,8)
        when -1
            @app.program.set_speed(1,2)
        when 0
            @app.program.set_speed(3,4)
        when 1
            @app.program.set_speed(1,1)
        when 2
            @app.program.set_speed(5,4)
        when 3
            @app.program.set_speed(3,2)
        when 4
            @app.program.set_speed(2,1)
        when 5
            @app.program.set_speed(5,2)
        when 6
            @app.program.set_speed(3,1)
        end
    end

    def on_jog(value)
        @app.preview.seek(value * 5)
    end

    def on_button_down(button)
        case button
        when 256
            prev_event
        when 257
            @app.program.stop
        when 258
            @app.preview.mark_in
            @app.program.shot = @app.preview.shot
        when 259
            next_event
        when 260
            if @shifted == 1
                preview_source 4
            else
                preview_source 0
            end
        when 261
            if @shifted == 1
                preview_source 5
            else
                preview_source 1
            end
        when 262
            if @shifted == 1
                preview_source 6
            else
                preview_source 2
            end
        when 263
            if @shifted == 1
                preview_source 7
            else
                preview_source 3
            end
        when 264
            @shifted = 2

        when 265
            store_shot
            #save_preview_shot 'rpi_goal'
        when 266
            store_shot
            #save_preview_shot 'rpi_penalty'
        #    capture_event
        when 267
            store_shot
            #save_preview_shot 'away_goal'
        #    capture_event
        when 268
            store_shot
            #save_preview_shot 'away_penalty'
        #    capture_event
        when 269
            capture_event
        when 270
            @app.mv_mode
        end


        if @shifted == 2
            @shifted = 1
        elsif @shifted == 1
            @shifted = 0
        end
    end

    def store_shot
        shot = @app.preview.shot
        @web_interface.send_shot(shot)
    end

    def save_preview_shot(prefix)
        shot = @app.preview.shot
        n = 0
        fn = sprintf('%s_%04d.mjpg', prefix, n)
        path = File.join(CLIP_BASE_PATH, fn)

        while File.exists?(path)
            n += 1
            fn = sprintf('%s_%04d.mjpg', prefix, n)
            path = File.join(CLIP_BASE_PATH, fn)
        end

        File.open(path, 'wb') do |file|
            (0..shot.length).each do |frame|
                file.write shot.frame(frame)
            end
        end
    end

    def tag_current_event(tag)
        @current_event.type = tag
        @web_interface.send_event(@current_event)
    end

    def preview_source(source)
        @current_preview_source = source
        @app.preview.shot = current_event.shots[source] if current_event.shots[source]
    end

    def capture_event
        @current_event = ReplayEvent.new
        @event_list << @current_event
        @event_ptr = @event_list.length - 1

        @current_event.id = @event_id
        @current_event.type = 'Uncategorized'
        @event_id += 1
        @current_event.shots = @app.each_source.map { |src| src.make_shot_now }
        @app.preview.shot = @current_event.shots[@current_preview_source]

        @web_interface.send_event(@current_event)
    end

    def prev_event
        @event_ptr = @event_ptr - 1
        if @event_ptr < 0
            @event_ptr = 0
        end

        @current_event = @event_list[@event_ptr]
        @app.preview.shot = @current_event.shots[@current_preview_source]

    end

    def next_event
        @event_ptr = @event_ptr + 1
        if @event_ptr >= @event_list.length
            @event_ptr = @event_list.length - 1
        end

        @current_event = @event_list[@event_ptr]
        @app.preview.shot = @current_event.shots[@current_preview_source]
    end

    def start_irb
        #IRB.start_session(binding())
        @app.start_irb
    end
end

class MjpegIterator
    def initialize(source, start, length)
        @source = source
        @pos = start
        @length = length
    end

    def each
        shot = Replay::ReplayShot.new
        shot.source = @source
        length = @length
        pos = @pos

        while length > 0
            shot.start = pos
            yield shot.preview
            length -= 1
            pos += 1
        end
    end
end

class RawAudioIterator
    def initialize(source, start, length
        @source = source
        @pos = start
        @length = length
    end

    def each
        shot = Replay::ReplayShot.new
        shot.source = @source
        shot.length = @length
        pos = @pos
        while length > 0
            shot.start = pos
            yield shot.audio
            length -= 1
            pos += 1
        end 
    end
end

class ReplayServer < Patchbay
    # Get all shots currently saved.
    get '/shots.json' do
        shots = []
        events.reverse_each do |evt|
            evt.shots.each_with_index do |shot, source|
                shots << shot.make_json(source)
            end 
        end
        render :json => shots.to_json
        #render :json => shots.map { |x| x.make_json( ) }.to_json
    end

    get '/events.json' do
        render :json => (events.each_with_index.map { |x, i| x.make_json( ) }).to_json
    end

    put '/clear_events' do
        @events = { }    
    end

    # Throw this shot up on the local operator's preview.
    put '/preview_shot.json' do
        replay_app.preview.shot = inbound_shot
        render :json => ''
    end

    # Roll this shot right now
    put '/roll_shot.json' do
        replay_app.program.shot = inbound_shot
        render :json => ''
    end

    # Roll the first shot right now, and roll the rest after it's done.
    put '/roll_queue.json' do
        unless inbound_shots.empty?
            replay_app.program.shot = inbound_shots.shift
            inbound_shots.each do |shot|
                replay_app.program.queue_shot(shot)
            end
        end

        render :json => ''
    end

    # Preview what's on the source right now.
    get '/sources/:id/preview.jpg' do
        src = params[:id].to_i
        shot = replay_app.source(src).make_shot_now
        render :jpg => shot.preview
    end

    # Preview a given timecode for a given source.
    get '/sources/:id/:timecode/preview.jpg' do
        tc = params[:timecode].to_i
        src = params[:id].to_i
        now = replay_app.source(src).make_shot_now
        
        if tc < 0 or tc > now.start
            render :json => '', :status => 404
        else
            shot = replay_app.source(src).make_shot_at(tc)
            render :jpg => shot.preview
        end
    end

    get '/sources/:id/:timecode/thumbnail.jpg' do
        tc = params[:timecode].to_i
        src = params[:id].to_i
        now = replay_app.source(src).make_shot_now
        
        if tc < 0 or tc > now.start
            render :json => '', :status => 404
        else
            shot = replay_app.source(src).make_shot_at(tc)
            render :jpg => shot.thumbnail
        end
    end

    get '/sources/:id/:start/:length/video.mjpg' do
        srcid = params[:id].to_i
        source = replay_app.source(srcid)
        start = params[:start].to_i
        length = params[:length].to_i

        render :mjpg => MjpegIterator.new(source, start, length)
    end

    get '/sources/:id/:start/:length/audio_2ch_48khz.raw' do
        srcid = params[:id].to_i
        source = replay_app.source(srcid)
        start = params[:start].to_i
        length = params[:length].to_i

        render :raw => RawAudioIterator.new(source, start, length)
    end

    get '/files.json' do
        ROLLOUT_DIR = '/root/rollout'
        render :json => Dir.glob(ROLLOUT_DIR + '/*.{mov,mpg}').to_json
    end

    put '/ffmpeg_rollout.json' do
        # DANGER DANGER DANGER
        # FIXME FIXME FIXME
        # THIS IS A GLARINC SECURITY HOLE
        p inbound_json
        filename = inbound_json["filename"]
        cmd = "ffmpeg -i \"#{filename}\" -f rawvideo -s 1920x1080 -pix_fmt uyvy422 pipe:%v -f s16le -ac 2 -ar 48000 pipe:%a </dev/null"
        p cmd
        replay_app.suspend_encode
        replay_app.program.avspipe_playout(cmd)
        render :json => ''
    end

    put '/resume_encode.json' do
        replay_app.resume_encode
        render :json => ''
    end

    self.files_dir = "public_html/"

    def events
        @events.values.sort_by! { |event| event.id }
    end

    def shots
        @shots
    end

    def send_shot(shot)
        @shots ||= []
        @shots << shot
    end

    def send_event(event)
        @events ||= { }
        @events[event.id] = event
    end

    attr_accessor :replay_app

private
    def inbound_shot
        unless params[:inbound_shot]
            inp = environment['rack.input']
            inp.rewind
            params[:inbound_shot] = Replay::ReplayShot.from_json(inp.read, replay_app.sources)
        end

        params[:inbound_shot]
    end

    def inbound_json
        unless params[:inbound_json]
            inp = environment['rack.input']
            inp.rewind
            params[:inbound_json] = JSON.parse(inp.read)
        end

        params[:inbound_json]
    end

    def inbound_shots
        unless params[:inbound_shots]
            inp = environment['rack.input']
            inp.rewind
            shots_json = JSON.parse(inp.read)
            params[:inbound_shots] = shots_json.map { |json| Replay::ReplayShot.from_json(json, replay_app.sources) }
        end

        params[:inbound_shots]
    end
end

server = ReplayServer.new
control = ReplayLocalControl.new(app)
control.web_interface = server
server.replay_app = app
Thread.new { server.run(:Host => '::0', :Port => 3000) }
Thin::Logging.debug = true
control.start_irb

