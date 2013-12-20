module Services
  module DocCollections
    class Find < Services::Base
      def call(ids, conditions = {})
        ids = Array(ids)
        scope = DocCollection.all
        scope = scope.where(id: ids) unless ids.empty?
        scope = scope.order("#{DocCollection.table_name}.id") unless conditions.key?(:order)
        conditions.each do |k, v|
          case k.to_sym
          when :slug
            scope = scope.where(k => v)
          when :docs
            scope = scope.joins(:doc_collection_memberships).where('doc_collection_memberships.doc_id' => v.map(&:id))
          else
            raise ArgumentError, "Unexpected condition: #{k}"
          end
        end
        scope
      end
    end
  end
end