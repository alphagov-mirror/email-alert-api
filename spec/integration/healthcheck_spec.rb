RSpec.describe "Healthcheck", type: :request do
  context "when the healthchecks pass" do
    it "returns a status of 'ok'" do
      get "/healthcheck"
      expect(data.fetch(:status)).to eq("ok")
    end
  end

  context "when one of the healthchecks is warning" do
    before do
      allow_any_instance_of(Healthcheck::QueueSize)
        .to receive(:queues)
        .and_return(default: 80000)
    end

    it "returns a status of 'warning'" do
      get "/healthcheck"
      expect(data.fetch(:status)).to eq("warning")
    end
  end

  it "includes useful information about each check" do
    get "/healthcheck"

    expect(data.fetch(:checks)).to include(
      database_connectivity: { status: "ok" },
      redis_connectivity:    { status: "ok" },
      sidekiq_queue_latency: hash_including(status: "ok", queues: a_kind_of(Hash)),
      sidekiq_queue_size:    hash_including(status: "ok", queues: a_kind_of(Hash)),
    )
  end
end
