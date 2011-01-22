require 'spec_helper'

describe VCR::Config do
  def stub_no_http_stubbing_adapter
    VCR.stub(:http_stubbing_adapter).and_raise(ArgumentError)
    VCR::Config.stub(:http_stubbing_libraries).and_return([])
  end

  describe '.cassette_library_dir=' do
    temp_dir(File.expand_path(File.dirname(__FILE__) + '/fixtures/config_spec'))

    it 'creates the directory if it does not exist' do
      expect { VCR::Config.cassette_library_dir = @temp_dir }.to change { File.exist?(@temp_dir) }.from(false).to(true)
    end

    it 'does not raise an error if given nil' do
      expect { VCR::Config.cassette_library_dir = nil }.to_not raise_error
    end
  end

  describe '.default_cassette_options' do
    it 'has a hash with some defaults even if it is set to nil' do
      VCR::Config.default_cassette_options = nil
      VCR::Config.default_cassette_options.should == { :match_requests_on => VCR::RequestMatcher::DEFAULT_MATCH_ATTRIBUTES }
    end

    it "returns #{VCR::RequestMatcher::DEFAULT_MATCH_ATTRIBUTES.inspect} for :match_requests_on when other defaults have been set" do
      VCR::Config.default_cassette_options = { :record => :none }
      VCR::Config.default_cassette_options.should == {
        :record            => :none,
        :match_requests_on => VCR::RequestMatcher::DEFAULT_MATCH_ATTRIBUTES
      }
    end
  end

  describe '.stub_with' do
    it 'stores the given symbols in http_stubbing_libraries' do
      VCR::Config.stub_with :fakeweb, :typhoeus
      VCR::Config.http_stubbing_libraries.should == [:fakeweb, :typhoeus]
    end
  end

  describe '.http_stubbing_libraries' do
    it 'returns an empty array even when the variable is nil' do
      VCR::Config.send(:remove_instance_variable, :@http_stubbing_libraries)
      VCR::Config.http_stubbing_libraries.should == []
    end
  end

  describe '.ignore_hosts' do
    let(:stubbing_adapter) { VCR::HttpStubbingAdapters::FakeWeb }
    before(:each) do
      stubbing_adapter.send(:ignored_hosts).should be_empty
      VCR.stub(:http_stubbing_adapter => stubbing_adapter)
      VCR::Config.ignored_hosts.should be_empty
    end

    it 'adds the given hosts to the ignored_hosts list' do
      VCR::Config.ignore_hosts 'example.com', 'example.net'
      VCR::Config.ignored_hosts.should == %w[ example.com example.net ]
      VCR::Config.ignore_host 'example.org'
      VCR::Config.ignored_hosts.should == %w[ example.com example.net example.org ]
    end

    it 'removes duplicate hosts' do
      VCR::Config.ignore_host 'example.com'
      VCR::Config.ignore_host 'example.com'
      VCR::Config.ignored_hosts.should == ['example.com']
    end

    it "updates the http_stubbing_adapter's ignored_hosts list" do
      VCR::Config.ignore_hosts 'example.com', 'example.org'
      stubbing_adapter.send(:ignored_hosts).should == %w[ example.com example.org ]
    end
  end

  describe '.ignore_localhost=' do
    before(:each) do
      VCR::Config.ignored_hosts.should be_empty
    end

    it 'adds the localhost aliases to the ignored_hosts list when set to true' do
      VCR::Config.ignore_host 'example.com'
      VCR::Config.ignore_localhost = true
      VCR::Config.ignored_hosts.should == ['example.com', *VCR::LOCALHOST_ALIASES]
    end

    it 'removes the localhost aliases from the ignored_hosts list when set to false' do
      VCR::Config.ignore_host 'example.com', *VCR::LOCALHOST_ALIASES
      VCR::Config.ignore_localhost = false
      VCR::Config.ignored_hosts.should == ['example.com']
    end
  end

  describe '.allow_http_connections_when_no_cassette=' do
    [true, false].each do |val|
      it "sets the allow_http_connections_when_no_cassette to #{val} when set to #{val}" do
        VCR::Config.allow_http_connections_when_no_cassette = val
        VCR::Config.allow_http_connections_when_no_cassette?.should == val
      end
    end

    it 'sets http_connnections_allowed to the default' do
      VCR.http_stubbing_adapter.should respond_to(:set_http_connections_allowed_to_default)
      VCR.http_stubbing_adapter.should_receive(:set_http_connections_allowed_to_default)
      VCR::Config.allow_http_connections_when_no_cassette = true
    end

    it "works when the adapter hasn't been set yet" do
      stub_no_http_stubbing_adapter
      VCR::Config.allow_http_connections_when_no_cassette = true
    end
  end

  describe '.uri_should_be_ignored?' do
    before(:each) { described_class.ignore_hosts 'example.com' }

    it 'returns true for a string URI with a host in the ignore_hosts list' do
      described_class.uri_should_be_ignored?("http://example.com/").should be_true
    end

    it 'returns true for a URI instance with a host in the ignore_hosts list' do
      described_class.uri_should_be_ignored?(URI("http://example.com/")).should be_true
    end

    it 'returns false for a string URI with a host in the ignore_hosts list' do
      described_class.uri_should_be_ignored?("http://example.net/").should be_false
    end

    it 'returns false for a URI instance with a host in the ignore_hosts list' do
      described_class.uri_should_be_ignored?(URI("http://example.net/")).should be_false
    end
  end
end
