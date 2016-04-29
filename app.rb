require 'prawn'

Prawn::Font::AFM.hide_m17n_warning = true

require 'barby'
require 'barby/barcode/code_128'
require 'barby/barcode/ean_13'
require 'barby/outputter/prawn_outputter'
require 'barby/outputter/png_outputter'

require 'sinatra/base'
require 'sinatra/reloader'
require 'erb'

module Label

    class Generator
        include Prawn::Measurements

        DEFAULT_WIDTH  = 54
        DEFAULT_HEIGHT = 17

        def execute(text, opts={})
            opts[:width]  ||= DEFAULT_WIDTH
            opts[:height] ||= DEFAULT_HEIGHT

            opts = {
                :page_size => [mm2pt(opts[:width]), mm2pt(opts[:height])],
                :layout    => :landscape,
                :margin    => 0,
                :info      => {
                    :Title => 'Barcode Generator'
                }
            }

            numbers = text.gsub(/[^0-9]+/, '')
            barcode = Barby::EAN13.new numbers
            out     = Barby::PrawnOutputter.new(barcode)

            doc = Prawn::Document.new(opts) do |pdf|
                pdf.bounding_box [ (pdf.bounds.width - out.width)/2, pdf.bounds.top - 4 ], :width => out.width, :height => pdf.bounds.height * 0.5 - 4 do
                    out.annotate_pdf(pdf, :height => pdf.bounds.height - 2, :xdim => 1)
                end

                pdf.font 'Helvetica'

                pdf.bounding_box [ 2, pdf.bounds.height * 0.45 - 2 ], :width => pdf.bounds.width - 4, :height => pdf.bounds.height * 0.3 - 4 do
                    pdf.text text, :align => :center, :size => 8
                end

                pdf.bounding_box [ 2, pdf.bounds.height * 0.25 - 2 ], :width => pdf.bounds.width - 4, :height => pdf.bounds.height * 0.25 - 4 do
                    pdf.text "Propriété de BetaMachine", :align => :center, :size => 5, :style => :italic
                end
            end

            doc.render
        end

    end

end # End of module Label


class App < Sinatra::Base

    set :public_folder, File.join(File.dirname(__FILE__), "assets")

    configure :development do
        register Sinatra::Reloader
    end

    get '/' do
        erb :index
    end

    get '/barcode/image/:text' do
        numbers = params[:text].gsub(/[^0-9]+/, '')
        halt 400 if numbers.length != 12

        barcode = Barby::EAN13.new(numbers)
        out     = Barby::PngOutputter.new(barcode)

        content_type 'image/png'
        out.to_png :height => 25
    end

    post '/barcode' do
        halt 400 unless params[:barcode]

        begin
            g    = Label::Generator.new
            data = g.execute(params[:barcode])

            content_type 'application/pdf'
            data
        rescue
            halt 400
        end
    end
end
