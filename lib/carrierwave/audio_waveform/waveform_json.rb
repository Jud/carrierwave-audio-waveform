require 'ruby-audio'
require 'fileutils'
require 'json'

module CarrierWave
  module AudioWaveform
    class WaveformJson
      DEFAULT_OPTIONS = {
        :method => :peak,
        :samples => 100,
        :amplitude => 1
      }
    
      # Scope these under Waveform so you can catch the ones generated by just this
      # class.
      class RuntimeError < ::RuntimeError;end;
      class ArgumentError < ::ArgumentError;end;
    
      class << self
        # Generate a Waveform JSON file from the given filename with the given options.
        #
        # Available options (all optional) are:
        #
        #   :method => The method used to read sample frames, available methods
        #     are peak and rms. peak is probably what you're used to seeing, it uses
        #     the maximum amplitude per sample to generate the waveform, so the
        #     waveform looks more dynamic. RMS gives a more fluid waveform and
        #     probably more accurately reflects what you hear, but isn't as
        #     pronounced (typically).
        #
        #     Can be :rms or :peak
        #     Default is :peak.
        #
        #   :samples => The amount of samples wanted. The may have ±10% of the
        #     samples requested.
        #
        #     Default is 1800.
        #
        #   :amplitude => The amplitude of the final values
        #     Default is 1.
        #
        #   :auto_width => msec per sample. This will overwrite the sample of the
        #     final waveform depending on the length of the audio file.
        #     Example:
        #       100 => 1 sample per 100 msec; a one minute audio file will result in a width of 600 samples
        #
        # Example:
        #   JsonWaveform.generate("Kickstart My Heart.wav")
        #   JsonWaveform.generate("Kickstart My Heart.wav", :method => :rms)
        #
        def generate(source, options={})
          options = DEFAULT_OPTIONS.merge(options)
          filename = options[:filename] || self.generate_json2_filename(source)
          raise ArgumentError.new("No source audio filename given, must be an existing sound file.") unless source
          raise RuntimeError.new("Source audio file '#{source}' not found.") unless File.exist?(source)
    
          if options[:auto_samples]
            RubyAudio::Sound.open(source) do |audio|
              options[:samples] = (audio.info.length * 1000 / options[:auto_samples].to_i).ceil
            end
          end
    
          # Frames gives the amplitudes for each channel, for our waveform we're
          # saying the "visual" amplitude is the average of the amplitude across all
          # the channels. This might be a little weird w/ the "peak" method if the
          # frames are very wide (i.e. the image width is very small) -- I *think*
          # the larger the frames are, the more "peaky" the waveform should get,
          # perhaps to the point of inaccurately reflecting the actual sound.
          samples = frames(source, options[:samples], options[:method]).collect do |frame|
            frame.inject(0.0) { |sum, peak| sum + peak } / frame.size
          end
    
          samples = normalize(samples, options)
          data_hash = build_hash(samples, options)
          
          File.open(filename, 'w') do |f|
            f.write data_hash.to_json
          end

          filename
        end

        def generate_json2_filename(source)
          ext = File.extname(source)
          source_file_path_without_extension = File.join File.dirname(source), File.basename(source, ext)
          "#{source_file_path_without_extension}.json"
        end
    
        private
    
        # Returns a sampling of frames from the given RubyAudio::Sound using the
        # given method
        def frames(source, samples, method = :peak)
          raise ArgumentError.new("Unknown sampling method #{method}") unless [ :peak, :rms ].include?(method)
    
          frames = []
    
          RubyAudio::Sound.open(source) do |audio|
            frames_read = 0
            frames_per_sample = (audio.info.frames.to_f / samples.to_f).to_i
            sample = RubyAudio::Buffer.new("float", frames_per_sample, audio.info.channels)
    
            while(frames_read = audio.read(sample)) > 0
              frames << send(method, sample, audio.info.channels)
            end
          end
    
          frames
        rescue RubyAudio::Error => e
          raise e unless e.message == "File contains data in an unknown format."
          raise JsonWaveform::RuntimeError.new("Source audio file #{source} could not be read by RubyAudio library -- Hint: non-WAV files are no longer supported, convert to WAV first using something like ffmpeg (RubyAudio: #{e.message})")
        end
    
        def normalize(samples, options)
          samples.map do |sample|
            # Half the amplitude goes above zero, half below
            amplitude = sample * options[:amplitude].to_f
            rounded = amplitude.round(2)
            rounded.zero? || rounded == 1 ? rounded.to_i : rounded
          end
        end

        def build_hash(samples, options)
          object = Hash.new()
          object[:data] = samples
          object.merge(options)
        end
    
        # Returns an array of the peak of each channel for the given collection of
        # frames -- the peak is individual to the channel, and the returned collection
        # of peaks are not (necessarily) from the same frame(s).
        def peak(frames, channels=1)
          peak_frame = []
          (0..channels-1).each do |channel|
            peak_frame << channel_peak(frames, channel)
          end
          peak_frame
        end
    
        # Returns an array of rms values for the given frameset where each rms value is
        # the rms value for that channel.
        def rms(frames, channels=1)
          rms_frame = []
          (0..channels-1).each do |channel|
            rms_frame << channel_rms(frames, channel)
          end
          rms_frame
        end
    
        # Returns the peak voltage reached on the given channel in the given collection
        # of frames.
        #
        # TODO: Could lose some resolution and only sample every other frame, would
        # likely still generate the same waveform as the waveform is so comparitively
        # low resolution to the original input (in most cases), and would increase
        # the analyzation speed (maybe).
        def channel_peak(frames, channel=0)
          peak = 0.0
          frames.each do |frame|
            next if frame.nil?
            frame = Array(frame)
            peak = frame[channel].abs if frame[channel].abs > peak
          end
          peak
        end
    
        # Returns the rms value across the given collection of frames for the given
        # channel.
        def channel_rms(frames, channel=0)
          Math.sqrt(frames.inject(0.0){ |sum, frame| sum += (frame ? Array(frame)[channel] ** 2 : 0) } / frames.size)
        end
      end
    end
  end
end
