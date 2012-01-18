require 'spec_helper'
require 'lib/authorization_rules'

describe Api::RepositoriesController, :katello => true do
  include LoginHelperMethods
  include AuthorizationHelperMethods
  include OrchestrationHelper
  include ProductHelperMethods
  include OrganizationHelperMethods

  let(:task_stub) do
    @task = mock(PulpTaskStatus)
    @task.stub(:save!).and_return(true)
    @task.stub(:to_json).and_return("")
    @task
  end
  let(:url) { "http://localhost" }
  let(:type) { "yum" }

  describe "rules" do
    before(:each) do
      disable_product_orchestration
      disable_user_orchestration

      @organization = new_test_org
      Organization.stub!(:first).and_return(@organization)
      @provider = Provider.create!(:provider_type=>Provider::CUSTOM, :name=>"foo1", :organization=>@organization)
      Provider.stub!(:find).and_return(@provider)
      @product = Product.new({:name => "prod"})

      @product.provider = @provider
      @product.environments << @organization.locker
      @product.stub(:arch).and_return('noarch')
      @product.save!
      Product.stub!(:find).and_return(@product)
      Product.stub!(:find_by_cp_id).and_return(@product)
      ep = EnvironmentProduct.find_or_create(@organization.locker, @product)
      @repository = Repository.create!(:environment_product => ep, :name=> "repo_1", :pulp_id=>"1")
      Repository.stub(:find).and_return(@repository)
      Pulp::Repository.stub(:start_discovery).and_return({})
      PulpSyncStatus.stub(:using_pulp_task).and_return(task_stub)
      Pulp::PackageGroup.stub(:all => {})
      Pulp::PackageGroupCategory.stub(:all => {})
    end
    describe "for create" do
      let(:action) {:create}
      let(:req) do
        post 'create', :name => 'repo_1', :url => 'http://www.repo.org', :product_id => 'product_1'
      end
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:update, :providers, @provider.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
    describe "for show" do
      let(:action) {:show}
      let(:req) { get :show, :id => 1 }
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:read, :providers, @provider.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
    describe "for destroy" do
      let(:action) {:destroy}
      let(:req) { get :destroy, :id => 1 }
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:update, :providers, @provider.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
    describe "for enable" do
      let(:action) {:enable}
      let(:req) { get :enable, :id => 1, :enable => 1 }
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:update, :providers, @provider.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
    describe "for discovery" do
      let(:action) {:discovery}
      let(:req) do
        post 'discovery', :organization_id => "ACME", :url => url, :type => type
      end
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:update, :organizations, @organization.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
    describe "for package_groups" do
      let(:action) {:package_groups}
      let(:req) { get :package_groups, :id => 1 }
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:read, :providers, @provider.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
    describe "for package_group_categories" do
      let(:action) {:package_group_categories}
      let(:req) { get :package_group_categories, :id => 1 }
      let(:authorized_user) do
        user_with_permissions { |u| u.can(:read, :providers, @provider.id, @organization) }
      end
      let(:unauthorized_user) do
        user_without_permissions
      end
      it_should_behave_like "protected action"
    end
  end

  context "unit tests" do
    before(:each) do
      @product = Product.new
      @organization = Organization.new
      @organization.id = 1
      @request.env["HTTP_ACCEPT"] = "application/json"
      login_user_api

      disable_authorization_rules
    end

    describe "create a repository" do
      it 'should call pulp and candlepin layer' do
        Product.should_receive(:find_by_cp_id).with('product_1').and_return(@product)
        @product.should_receive(:add_repo).and_return({})

        post 'create', :name => 'repo_1', :url => 'http://www.repo.org', :product_id => 'product_1'
      end

      context 'there is already a repo for the product with the same name' do
        before do
          Product.stub(:find_by_cp_id => @product)
          @product.stub(:add_repo).and_return { raise Errors::ConflictException }
        end

        it "should notify about conflict" do
          post 'create', :name => 'repo_1', :url => 'http://www.repo.org', :product_id => 'product_1'
          response.code.should == '409'
        end
      end

    end

    describe "show a repository" do
      it 'should call pulp glue layer' do
        repo_mock = mock(Glue::Pulp::Repo)
        Repository.should_receive(:find).with("1").and_return(repo_mock)
        repo_mock.should_receive(:to_hash)
        get 'show', :id => '1'
      end
    end

    describe "repository discovery" do
      it "should call Pulp::Proxy.post" do
        Pulp::Repository.should_receive(:start_discovery).with(url, type).once.and_return({})
        PulpSyncStatus.should_receive(:using_pulp_task).with({}).and_return(task_stub)
        Organization.stub!(:first).and_return(@organization)

        post 'discovery', :organization_id => "ACME", :url => url, :type => type
      end
    end

    describe "get list of repository package groups" do
      subject { get :package_groups, :id => "123" }
      before do
          @repo = Repository.new(:pulp_id=>"123", :id=>"123")
          Repository.stub(:find).and_return(@repo)
          Pulp::PackageGroup.stub(:all => {})
      end
      it "should call Pulp layer" do
        Pulp::PackageGroup.should_receive(:all).with("123")
        subject
      end
      it { should be_success }
    end

    describe "get list of repository package categories" do
      subject { get :package_group_categories, :id => "123" }

      before do
          @repo = Repository.new(:pulp_id=>"123", :id=>"123")
          Repository.stub(:find).and_return(@repo)
          Pulp::PackageGroupCategory.stub(:all => {})
      end
      it "should call Pulp layer" do
        Pulp::PackageGroupCategory.should_receive(:all).with("123")
        subject
      end
      it { should be_success }
    end
  end

end
