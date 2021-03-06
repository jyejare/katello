require "katello_test_helper"

module Katello
  class Api::V2::DockerManifestsControllerTest < ActionController::TestCase
    def models
      @repo = Repository.find(katello_repositories(:redis).id)
      @manifest = @repo.docker_manifests.create!(:digest => "abc123", :uuid => "123xyz")
    end

    def setup
      setup_controller_defaults_api
      models
    end

    def test_index
      get :index
      assert_response :success
      assert_template "katello/api/v2/docker_manifests/index"
    end

    def test_index_with_repository
      get :index, params: { :repository_id => @repo.id }
      assert_response :success
      assert_template "katello/api/v2/docker_manifests/index"
    end

    def test_index_with_organization
      get :index, params: { :organization_id => @repo.organization.id }
      assert_response :success
      assert_template "katello/api/v2/docker_manifests/index"
    end

    def test_index_with_content_view_version
      get :index, params: { :content_view_version_id => ContentViewVersion.last }
      assert_response :success
      assert_template "katello/api/v2/docker_manifests/index"
    end

    def test_show
      get :show, params: { :repository_id => @repo.id, :id => @manifest.uuid }

      assert_response :success
      assert_template "katello/api/v2/docker_manifests/show"
    end

    def test_compare
      @lib_repo = katello_repositories(:rhel_6_x86_64)
      @view_repo = katello_repositories(:rhel_6_x86_64_library_view_1)

      get :compare, params: { :content_view_version_ids => [@lib_repo.content_view_version_id, @view_repo.content_view_version_id] }
      assert_response :success
      assert_template "katello/api/v2/docker_manifests/compare"

      get :compare, params: { :content_view_version_ids => [@lib_repo.content_view_version_id, @view_repo.content_view_version_id], :repository_id => @lib_repo.id }
      assert_response :success
      assert_template "katello/api/v2/docker_manifests/compare"
    end
  end
end
