SYMBOLS = [
  #(0x2190...0x21FF), # Arrows
  #(0x2200...0x22FF), # Mathematical Operators
  #(0x2500...0x257F), # Box Drawing
  (0x2580...0x259F), # Block Elements
  (0x25A0...0x25FF), # Geometric Shapes
  #(0x2600...0x26FF), # Miscellaneous Symbols
].map(&:to_a).flatten.map { |i| i.chr(Encoding::UTF_8) }

module CSTG
  class Application

    def self.call(*arguments)
      new(*arguments).call
    end

    def initialize(arguments)
      @arguments         = arguments
      @available_symbols = SYMBOLS.dup
      @pixel_symbols     = {}
    end

    def call
      validate_argument_length
      retrieve_paths
      validate_image_path
      load_image
      generate_pdf
    end

    protected

    def validate_argument_length
      if @arguments.length != 2
        puts "Error: Incorrect arguments given"
        puts "Usage: cstg INPUT_IMAGE OUTPUT_PDF"
        exit 1
      end
    end

    def retrieve_paths
      @input_path  = File.expand_path(@arguments.first)
      @output_path = File.expand_path(@arguments.last)
    end

    def validate_image_path
      unless File.exists?(@input_path)
        puts "Error: Image path does not exist"
        exit 1
      end
    end

    def load_image
      @image = begin
        Magick::Image.read(@input_path).first
      rescue Magick::ImageMagickError
        puts "Error: Could not read image"
        exit 1
      end
    end

    RGB_HEX_FORMAT = "%02x" * 3

    def generate_pdf
      FileUtils.mkdir_p(File.dirname(@output_path))

      Prawn::Document.generate(@output_path) do |pdf|
        pixel_size_x = pdf.bounds.right / @image.columns.to_f
        pixel_size_y = pdf.bounds.top / @image.rows.to_f
        pixel_size   = [pixel_size_x, pixel_size_y].min

        pdf.font("assets/dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf")

        pdf.stroke do
          @image.each_pixel do |pixel, pixel_x, pixel_y|
            draw_pixel(pdf, pixel, pixel_x, pixel_y, pixel_size)
          end
        end

      end
    end

    def pixel_hex(pixel)
      RGB_HEX_FORMAT % [pixel.red / 256, pixel.green / 256, pixel.blue / 256]
    end

    def draw_pixel(pdf, pixel, pixel_x, pixel_y, pixel_size)
      pixel_hex = pixel_hex(pixel)
      pdf.fill_color pixel_hex

      x = pixel_x * pixel_size
      y = pdf.bounds.top - pixel_y * pixel_size

      pdf.stroke_rectangle [x, y], pixel_size, pixel_size
      draw_icon(pdf, x, y, pixel_size, pixel_size / 8, pixel_hex) unless pixel.alpha == 0
    end

    def draw_icon(pdf, x, y, size, padding, pixel_hex)
      circle_x    = x + (size / 2)
      circle_y    = y - (size / 2)
      circle_size = size - (padding * 2)

      pdf.fill_circle [circle_x, circle_y], circle_size / 2

      pdf.fill_color "ffffff"

      @pixel_symbols[pixel_hex] ||= @available_symbols.delete_at(rand(@available_symbols.size))
      pixel_symbol = @pixel_symbols[pixel_hex]
      pdf.text_box pixel_symbol, at: [x, y], width: size, height: size, align: :center, valign: :center, overflow: :shrink_to_fit
    end

  end
end

