require 'carrierwave'
require 'carrierwave/audio_waveform/waveformer'
require 'carrierwave/audio_waveform/waveform_data'
require 'carrierwave/audio_waveform/waveform_peaks'
require 'carrierwave/audio_waveform/waveform_svg'

module CarrierWave
  module AudioWaveform
    module ClassMethods
      extend ActiveSupport::Concern

      def waveform options={}
        process waveform: [ options ]
      end

      def waveform_data options={}
        process waveform_data: [ options ]
      end

      def waveform_peaks options={}
        process waveform_peaks: [ options ]
      end

      def waveform_svg options={}
        process waveform_svg: [ options ]
      end
    end

    def waveform options={}
      cache_stored_file! if !cached?

      image_filename = Waveformer.generate(current_path, options)
      File.rename image_filename, current_path

      if options[:type] == :svg
        self.file.instance_variable_set(:@content_type, "image/svg+xml")
      else
        self.file.instance_variable_set(:@content_type, "image/png")
      end
    end

    def waveform_data options={}
      cache_stored_file! if !cached?

      data_filename = WaveformData.generate(current_path, options)
      File.rename data_filename, current_path
      self.file.instance_variable_set(:@content_type, "application/json")
    end

    def waveform_peaks options={}
      cache_stored_file! if !cached?

      data_filename = WaveformPeaks.generate(current_path, options)
      File.rename data_filename, current_path
      self.file.instance_variable_set(:@content_type, "application/json")
    end

    def waveform_svg options={}
      cache_stored_file! if !cached?

      data_filename = WaveformSvg.generate(current_path, options)
      File.rename data_filename, current_path
      self.file.instance_variable_set(:@content_type, "image/svg+xml")
    end
  end
end
