require_relative '../../spec_helper'

module ThreeScale
  module Backend
    module Stats
      describe Cleaner do
        let(:storage) { Backend::Storage.instance }
        let(:non_proxied_instances) { storage.send(:non_proxied_instances) }

        # These are hashes Redis key-value
        let(:keys_not_to_be_deleted) { fixtures_redis_keys }
        let(:keys_to_be_deleted) { fixtures_redis_keys_to_delete }
        let(:all_keys) { keys_not_to_be_deleted.merge(keys_to_be_deleted) }

        let(:services_to_be_deleted) do # According to the fixtures defined
          ['service_to_delete_1', 'service_to_delete_2']
        end

        let(:redis_set_marked_to_be_deleted) do
          described_class.const_get(:KEY_SERVICES_TO_DELETE)
        end

        let(:logger) { object_double(Backend.logger) }
        before do
          allow(logger).to receive(:info)
          allow(described_class).to receive(:logger).and_return(logger)
        end

        describe 'delete' do
          before do # Fill Redis
            all_keys.each { |k, v| storage.set(k, v) }
          end

          context 'when there are services marked to be deleted' do
            before do
              services_to_be_deleted.each do |service|
                Cleaner.mark_service_to_be_deleted(service)
              end
            end

            it 'deletes only the stats of services marked to be deleted' do
              Cleaner.delete!(non_proxied_instances)

              expect(keys_not_to_be_deleted.keys.all? { |key| storage.exists(key) })
                .to be true

              expect(keys_to_be_deleted.keys.none? { |key| storage.exists(key) })
                .to be true
            end

            it 'deletes the services from the set of marked to be deleted' do
              Cleaner.delete!(non_proxied_instances)

              expect(storage.smembers(redis_set_marked_to_be_deleted)).to be_empty
            end
          end

          context 'when there are no services marked to be deleted' do
            before { storage.del(redis_set_marked_to_be_deleted) }

            it 'does not delete any keys' do
              expect(all_keys.keys.all? {|key| storage.exists(key) })
            end
          end

          context 'with the option to log deleted keys enabled' do
            let(:log_to) { double(STDOUT) }

            before do
              allow(log_to).to receive(:puts)

              services_to_be_deleted.each do |service|
                Cleaner.mark_service_to_be_deleted(service)
              end
            end

            it 'logs the deleted keys, one per line' do
              Cleaner.delete!(non_proxied_instances, log_deleted_keys: log_to)

              keys_to_be_deleted.each do |k, v|
                expect(log_to).to have_received(:puts).with("#{k} #{v}")
              end
            end

            it 'deletes only the stats of services marked to be deleted' do
              Cleaner.delete!(non_proxied_instances, log_deleted_keys: log_to)

              expect(keys_not_to_be_deleted.keys.all? { |key| storage.exists(key) })
                .to be true

              expect(keys_to_be_deleted.keys.none? { |key| storage.exists(key) })
                .to be true
            end

            it 'deletes the services from the set of marked to be deleted' do
              Cleaner.delete!(non_proxied_instances, log_deleted_keys: log_to)

              expect(storage.smembers(redis_set_marked_to_be_deleted)).to be_empty
            end
          end
        end

        private

        # The two helpers below are just used to fill Redis with some keys

        def fixtures_redis_keys
          {
            # Non-stats keys
            k1: 'v1', k2: 'v2', k3: 'v3',

            # Starts with "stats/" but it's not a stats key, it's used for the
            # "first traffic" event.
            'stats/{service:s1}/cinstances' => 'some_val',

            # Legacy or corrupted keys that look like stats keys but should be
            # ignored.
            'stats/{service:s1}/city:/metric:m1/day:20191216' => 1, # 'city' no longer used
            'stats/{service:s1}/%?!`:m1/day:20191216' => 2, # corrupted.

            # Stats keys, service level
            'stats/{service:s1}/metric:m1/day:20191216' => 10,
            'stats/{service:s1}/metric:m1/year:20190101' => 100,

            # Stats keys, app level
            'stats/{service:s1}/cinstance:app1/metric:m1/day:20191216' => 10,
            'stats/{service:s1}/cinstance:app1/metric:m1/year:20190101' => 100,

            # Response codes
            'stats/{service:s2}/response_code:200/day:20191216' => 2,
            'stats/{service:s2}/cinstance:app2/response_code:200/day:20191216' => 3
          }
        end

        def fixtures_redis_keys_to_delete
          {
            # Stats keys, service level
            'stats/{service:service_to_delete_1}/metric:m1/day:20191216' => 10,
            'stats/{service:service_to_delete_2}/metric:m1/year:20190101' => 100,

            # Stats keys, app level
            'stats/{service:service_to_delete_1}/cinstance:app1/metric:m1/day:20191216' => 10,
            'stats/{service:service_to_delete_2}/cinstance:app1/metric:m1/year:20190101' => 100,

            # Response codes
            'stats/{service:service_to_delete_1}/response_code:200/day:20191216' => 2,
            'stats/{service:service_to_delete_2}/cinstance:app2/response_code:200/day:20191216' => 3
          }
        end
      end
    end
  end
end
