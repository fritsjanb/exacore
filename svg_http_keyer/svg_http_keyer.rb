#!/usr/bin/env ruby 

require 'rubygems'
require 'patchbay'
require 'thin'
require 'base64'

Thin::Logging.silent = true

IN = 1
OUT = 2
UP = 3
DOWN = 4

$svgdata = ''
$trans_i = 0
$trans_nframes = 0
$trans_state = DOWN
$dirty_level = 0

# talk to stdio
Thread.new do
    begin
        while true
            # await request
            dummy = STDIN.read(1)
            if dummy.nil?
                break
            end


            # dissolve state logic
            Thread.exclusive do
                size = [ $svgdata.length ].pack('L')
                alpha = 0

                if $trans_state == UP
                    alpha = 255
                elsif $trans_state == DOWN
                    alpha = 0
                elsif $trans_state == IN 
                    alpha = ($trans_i.to_f / $trans_nframes.to_f * 255.0).to_i
                    $trans_i += 1
                    if $trans_i >= $trans_nframes
                        $trans_state = UP
                    end
                elsif $trans_state == OUT 
                    alpha = (255.0 - ($trans_i.to_f / $trans_nframes.to_f * 255.0)).to_i

                    $trans_i += 1
                    if $trans_i >= $trans_nframes
                        $trans_state = DOWN
                    end
                end

                alphastr = [ alpha, $dirty_level ].pack('CC')

                STDOUT.write(size)
                STDOUT.write(alphastr)
                STDOUT.write($svgdata)
                STDOUT.flush

                $svgdata = ''
            end

        end
    rescue Exception, e
        STDERR.puts "exception in IO thread"
        exit 1
    end
end

class KeyerServer < Patchbay
    post '/key' do
        # read the postdata into template
        Thread.exclusive do
            data = incoming_data
            STDERR.puts "new key was written #{data.length}"
            File.open('/tmp/lastkey.svg', 'wb') do |f|
                f.write data
            end
            $svgdata = data
        end
        render :json => ''
    end

    put '/key' do
        # read the postdata into template
        Thread.exclusive do
            data = incoming_data
            STDERR.puts "new key was written #{data.length}"
            File.open('/tmp/lastkey.svg', 'wb') do |f|
                f.write data
            end
            $svgdata = data
        end
        render :json => ''
    end

    put '/key_dataurl' do
        data = incoming_data
        md = /^data:image\/png;base64,/.match(data)
        if (md) 
            rawdata = Base64.decode64(md.post_match)
            Thread.exclusive do
                $svgdata = rawdata
            end
        end
    end

    post '/dissolve_in/:frames' do
        Thread.exclusive do
            if $trans_state == DOWN
                $trans_nframes = params[:frames].to_i
                $trans_i = 0
                $trans_state = IN
                render :json => ''
            else
                render :json => '', :status => 503
            end
        end
    end

    post '/dirty_level/:n' do
        Thread.exclusive do
            $dirty_level = params[:n].to_i
        end
        render :json => ''
    end

    post '/dissolve_out/:frames' do
        Thread.exclusive do
            if $trans_state == UP
                $trans_nframes = params[:frames].to_i
                $trans_i = 0
                $trans_state = OUT
                render :json => ''
            else
                render :json => '', :status => 503
            end
        end
    end

    def incoming_data
        unless params[:incoming_data]
            inp = environment['rack.input']
            inp.rewind
            params[:incoming_data] = inp.read
        end

        params[:incoming_data]
    end

    self.files_dir = 'public_html'
end

app = KeyerServer.new
app.run(:Host => '::', :Port => 4567)
