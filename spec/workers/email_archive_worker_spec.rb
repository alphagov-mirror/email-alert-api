RSpec.describe EmailArchiveWorker do
  describe "#perform" do
    def perform
      described_class.new.perform
    end

    context "when there are no emails to archive" do
      before do
        create(:archived_email)
      end
      it "doesn't change the number of EmailArchive records" do
        expect { perform }
          .not_to(change { Email.where.not(archived_at: nil).count })
      end
    end

    context "when there are emails to archive" do
      let!(:email) { create(:email) }

      context "when archiving is disabled" do
        around do |example|
          ClimateControl.modify(EMAIL_ARCHIVE_S3_ENABLED: nil) { example.run }
        end

        it "does not use the S3EmailArchiveService" do
          expect(S3EmailArchiveService).not_to receive(:call)
          perform
        end

        it "does not set the EmailArchive entry as archived" do
          perform
          expect(Email.find(email.id).archived_at).to be_nil
        end
      end

      context "when archiving is enabled" do
        before { Aws.config[:s3] = { stub_responses: true } }

        around do |example|
          env_vars = {
            EMAIL_ARCHIVE_S3_BUCKET: "my-bucket",
            EMAIL_ARCHIVE_S3_ENABLED: "yes",
          }
          ClimateControl.modify(env_vars) { example.run }
        end

        it "Uses the S3EmailArchiveService" do
          expect(S3EmailArchiveService).to receive(:call)
          perform
        end

        it "sets the EmailArchive entry as archived" do
          perform
          expect(Email.find(email.id).archived_at).not_to be nil
        end
      end
    end
  end
end
