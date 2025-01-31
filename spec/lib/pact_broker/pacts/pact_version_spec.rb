require 'pact_broker/pacts/pact_version'

module PactBroker
  module Pacts
    describe PactVersion do

      describe "pacticipant names" do
        subject(:pact_version) do
          TestDataBuilder.new
            .create_consumer("consumer")
            .create_provider("provider")
            .create_consumer_version("1.0.1")
            .create_pact
          PactVersion.order(:id).last
        end

        its(:consumer_name) { is_expected.to eq("consumer") }
        its(:provider_name) { is_expected.to eq("provider") }
      end

      describe "#latest_pact_publication" do

        context "when the latest pact publication is not an overwritten one" do
          before do
            TestDataBuilder.new
              .create_provider("Bar")
              .create_consumer("Foo")
              .create_consumer_version("1.2.100")
              .create_pact
              .revise_pact
              .create_consumer_version("1.2.101")
              .create_pact
              .create_consumer_version("1.2.102")
              .create_pact
              .revise_pact
              .create_provider("Animals")
              .create_pact
              .create_provider("Wiffles")
              .create_pact
          end

          it "returns the latest pact publication for the given pact version" do
            pact = PactBroker::Pacts::Repository.new.find_pact("Foo", "1.2.102", "Animals")
            pact_version = PactBroker::Pacts::PactVersion.find(sha: pact.pact_version_sha)
            latest_pact_publication = pact_version.latest_pact_publication
            expect(latest_pact_publication.id).to eq pact.id
          end
        end

        context "when the only pact publication with the given sha is an overwritten one" do
          let(:td) { TestDataBuilder.new }
          let!(:first_version) do
            td.create_provider("Bar")
              .create_consumer("Foo")
              .create_consumer_version("1")
              .create_pact
              .and_return(:pact)
          end
          let!(:second_revision) do
            td.revise_pact
          end

          it "returns the overwritten pact publication" do
            pact_version = PactBroker::Pacts::PactVersion.find(sha: first_version.pact_version_sha)
            latest_pact_publication = pact_version.latest_pact_publication
            expect(latest_pact_publication.revision_number).to eq 1
          end
        end
      end

      describe "#latest_consumer_version_number" do
        before do
          PactBroker.configuration.order_versions_by_date = false
          builder = TestDataBuilder.new
          builder
            .create_consumer
            .create_provider
            .create_consumer_version("1.0.1")
            .create_pact
            .create_consumer_version("1.0.0")
            second_consumer_version = builder.and_return(:consumer_version)
            pact_publication = PactBroker::Pacts::PactPublication.order(:id).last
            new_params = pact_publication.to_hash
            new_params.delete(:id)
            new_params[:revision_number] = 2
            new_params[:consumer_version_id] = second_consumer_version.id

            PactBroker::Pacts::PactPublication.create(new_params)
        end

        it "returns the latest consumer version that has a pact that has this content" do
          expect(PactVersion.first.latest_consumer_version_number).to eq "1.0.1"
        end
      end

      describe "#latest_verification" do
        before do
          td.create_pact_with_hierarchy
            .create_verification
            .create_verification(number: 2)
            .create_verification(number: 3)
        end
        let(:pact_version) { PactVersion.last }

        subject { pact_version.latest_verification }

        it "returns the latest verification by execution date" do
          expect(subject.number).to eq 3
        end
      end
    end
  end
end
