if RUBY_VERSION >= '1.9'
  require 'csv'
else
  require 'fastercsv'
  CSV = FasterCSV
end

module Typus
  module Controller
    module Format

      protected

      def generate_html
        items_per_page = @resource.typus_options_for(:per_page)
        @items = @resource.page(params[:page]).per(items_per_page)
      end

      #--
      # TODO: Find in batches only works properly if it's used on models, not
      #       controllers, so in this action does nothing. We should find a way
      #       to be able to process large amounts of data.
      #++
      def generate_csv
        fields = @resource.typus_fields_for(:csv)

        filename = Rails.root.join("tmp", "export-#{@resource.to_resource}-#{Time.zone.now.to_s(:number)}.csv")

        options = { :conditions => @conditions, :batch_size => 1000 }

        ::CSV.open(filename, 'w') do |csv|
          csv << fields.keys
          @resource.find_in_batches(options) do |records|
            records.each do |record|
              csv << fields.map do |key, value|
                       case value
                       when :transversal
                         a, b = key.split(".")
                         record.send(a).send(b)
                       when :belongs_to
                         record.send(key).try(:to_label)
                       else
                         record.send(key)
                       end
                     end
            end
          end
        end

        send_file filename
      end

      def generate_json
        export(:json)
      end

      def generate_xml
        export(:xml)
      end

      def export(format)
        fields = @resource.typus_fields_for(format).map { |i| i.first }
        methods = fields - @resource.column_names
        except = @resource.column_names - fields
        render format => @resource.send("to_#{format}", :methods => methods, :except => except)
      end

    end
  end
end
