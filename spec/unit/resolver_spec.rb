require File.expand_path('../../spec_helper', __FILE__)

describe "Pod::Resolver" do
  before do
    Pod::Spec::Set.reset!
    @config_before = config
    Pod::Config.instance = nil
    config.silent = true
    config.repos_dir = fixture('spec-repos')
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'ASIWebPageRequest'
    end
    config.rootspec = @podfile
  end

  after do
    Pod::Config.instance = @config_before
  end

  it "has a ResolveContext which holds global state, such as cached specification sets" do
    resolver = Pod::Resolver.new
    resolver.resolve(@podfile)
    resolver.context.sets.values.sort_by(&:name).should == [
      Pod::Spec::Set.new(config.repos_dir + 'master/ASIHTTPRequest'),
      Pod::Spec::Set.new(config.repos_dir + 'master/ASIWebPageRequest'),
      Pod::Spec::Set.new(config.repos_dir + 'master/Reachability'),
    ].sort_by(&:name)
  end

  it "returns all specs needed for the dependency" do
    specs = Pod::Resolver.new.resolve(@podfile)
    specs.map(&:class).uniq.should == [Pod::Specification]
    specs.map(&:name).sort.should == %w{ ASIHTTPRequest ASIWebPageRequest Reachability }
  end

  it "does not raise if all dependencies match the platform of the root spec (Podfile)" do
    resolver = Pod::Resolver.new

    @podfile.platform :ios
    lambda { resolver.resolve(@podfile) }.should.not.raise
    @podfile.platform :osx
    lambda { resolver.resolve(@podfile) }.should.not.raise
  end

  it "raises once any of the dependencies does not match the platform of the root spec (Podfile)" do
    resolver = Pod::Resolver.new
    set = Pod::Spec::Set.new(config.repos_dir + 'master/ASIHTTPRequest')
    resolver.context.sets['ASIHTTPRequest'] = set

    def set.stub_platform=(platform); @stubbed_platform = platform; end
    def set.specification; spec = super; spec.platform = @stubbed_platform; spec; end

    @podfile.platform :ios
    set.stub_platform = :ios
    lambda { resolver.resolve(@podfile) }.should.not.raise
    set.stub_platform = :osx
    lambda { resolver.resolve(@podfile) }.should.raise Pod::Informative

    @podfile.platform :osx
    set.stub_platform = :osx
    lambda { resolver.resolve(@podfile) }.should.not.raise
    set.stub_platform = :ios
    lambda { resolver.resolve(@podfile) }.should.raise Pod::Informative
  end

  it "resolves subspecs" do
    @podfile = Pod::Podfile.new do
      platform :ios
      dependency 'RestKit/Network'
      dependency 'RestKit/ObjectMapping'
    end
    config.rootspec = @podfile
    resolver = Pod::Resolver.new
    resolver.resolve(@podfile).map(&:name).sort.should == %w{
      LibComponentLogging-Core
      LibComponentLogging-NSLog
      RestKit
      RestKit/Network
      RestKit/ObjectMapping
    }
  end
end

