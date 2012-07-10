module ThreeScale
  module Backend
    module Aggregator
      # Job for writing stats to cassandra 
      class StatsJob
          
        @queue = :main

        def self.perform(bucket)
    
          return unless Aggregator.cassandra_enabled?
       
          buckets_to_save = Aggregator.get_old_buckets_to_process(bucket)
          
          return if buckets_to_save.nil? || buckets_to_save.empty?
          
          buckets_to_save.each do |b|
            ## it will save all the changed keys from the oldest time bucket. If it
            ## fails it will but the bucket back to the set to that it can be processed
            ## by another StatsJob
            Aggregator.save_to_cassandra(b)
          end
          
        end

      end
    end
  end
end