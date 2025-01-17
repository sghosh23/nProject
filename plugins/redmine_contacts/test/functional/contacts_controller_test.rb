# encoding: utf-8
#
# This file is a part of Redmine CRM (redmine_contacts) plugin,
# customer relationship management plugin for Redmine
#
# Copyright (C) 2011-2014 Kirill Bezrukov
# http://www.redminecrm.com/
#
# redmine_contacts is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_contacts is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_contacts.  If not, see <http://www.gnu.org/licenses/>.

# encoding: utf-8
require File.expand_path('../../test_helper', __FILE__)

class ContactsControllerTest < ActionController::TestCase
  fixtures :projects,
           :users,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries

    ActiveRecord::Fixtures.create_fixtures(File.dirname(__FILE__) + '/../fixtures/',
                            [:contacts,
                             :contacts_projects,
                             :contacts_issues,
                             :deals,
                             :notes,
                             :roles,
                             :enabled_modules,
                             :tags,
                             :taggings,
                             :contacts_queries])


  def setup
    RedmineContacts::TestCase.prepare

    @controller = ContactsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    User.current = nil
  end

  test "should get index" do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    assert_not_nil Contact.find(1)

    get :index
    assert_response :success
    assert_template :index
    assert_not_nil assigns(:contacts)
    assert_not_nil assigns(:tags)
    assert_nil assigns(:project)
    assert_tag :tag => 'a', :content => /Domoway/
    assert_tag :tag => 'a', :content => /Marat/
    assert_tag :tag => 'h3', :content => /Tags/
    assert_tag :tag => 'h3', :content => /Recently viewed/

    assert_select 'div#tags span#single_tags span.tag-label-color a', "main (2)"
    assert_select 'div#tags span#single_tags span.tag-label-color a', "test (2)"

    # private projects hidden
    # assert_no_tag :tag => 'a', :content => /Issue of a private subproject/
    # assert_no_tag :tag => 'a', :content => /Issue on project 2/
    # project column
    # assert_tag :tag => 'th', :content => /Project/
  end

  test "should get index in project" do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 1
    Setting.default_language = 'en'

    get :index, :project_id => 1
    assert_response :success
    assert_template :index
    assert_not_nil assigns(:contacts)
    assert_not_nil assigns(:project)
    assert_tag :tag => 'a', :content => /Domoway/
    assert_tag :tag => 'a', :content => /Marat/
    assert_tag :tag => 'h3', :content => /Tags/
    assert_tag :tag => 'h3', :content => /Recently viewed/

  end

  test "should not absolute links" do
    @request.session[:user_id] = 1
    get :index
    assert_response :success
    # assert_equal 'localhost', @response.body
    assert_no_match /localhost/, @response.body
  end

  test "should get index deny user in project" do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 5

    get :index, :project_id => 1
    assert_response :redirect
    # assert_tag :tag => 'div', :attributes => { :id => "login-form"}
    # assert_select 'div#login-form'
  end

  test "should get index with filters" do
    @request.session[:user_id] = 1
    get :index, :is_company => ActiveRecord::Base.connection.quoted_true.gsub(/'/, '')
    assert_response :success
    assert_template :index
    assert_select 'div#content div#contact_list table.contacts td.name h1 a', 'Domoway'
  end

  test "should get show" do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 2
    Setting.default_language = 'en'

    get :show, :id => 3, :project_id => 1
    assert_response :success
    assert_template :show
    assert_not_nil assigns(:contact)
    assert_not_nil assigns(:project)
    assert_tag :tag => 'h1', :content => /Domoway/

    assert_select 'div#tags_data span.tag-label-color a', 'main'
    assert_select 'div#tags_data span.tag-label-color a', 'test'

    assert_select 'div#company_contacts h4.contacts_header a', /Marat Aminov/
    assert_select 'div#company_contacts h4.contacts_header a', /Ivan Ivanov/

    assert_select 'div#comments div#notes table.note_data td.name h4', 4

    assert_select 'h3', "Recently viewed"
  end
  test "should get new" do
    @request.session[:user_id] = 2
    get :new, :project_id => 1
    assert_response :success
    assert_template 'new'
    assert_select 'input#contact_first_name'
  end

  test "should not get new by deny user" do
    @request.session[:user_id] = 4
    get :new, :project_id => 1
    assert_response :forbidden
  end

  test "should post create" do
    @request.session[:user_id] = 1
    assert_difference 'Contact.count' do
      post :create, :project_id => 1,
                    :contact => {
                                :company => "OOO \"GKR\"",
                                :is_company => 0,
                                :job_title => "CFO",
                                :assigned_to_id => 3,
                                :tag_list => "test,new",
                                :last_name => "New",
                                :middle_name => "Ivanovich",
                                :first_name => "Created"}

    end
    assert_redirected_to :controller => 'contacts', :action => 'show', :id => Contact.last.id, :project_id => Contact.last.project

    contact = Contact.find(:first, :conditions => {:first_name => "Created", :last_name => "New", :middle_name => "Ivanovich"})
    assert_not_nil contact
    assert_equal "CFO", contact.job_title
    assert_equal ["new", "test"], contact.tag_list.sort
    assert_equal 3, contact.assigned_to_id
  end

  test "should not post create by deny user" do
    @request.session[:user_id] = 4
    post :create, :project_id => 1,
        :contact => {
                    :company => "OOO \"GKR\"",
                    :is_company => 0,
                    :job_title => "CFO",
                    :assigned_to_id => 3,
                    :tag_list => "test,new",
                    :last_name => "New",
                    :middle_name => "Ivanovich",
                    :first_name => "Created"}
    assert_response :forbidden
  end

  test "should get edit" do
    @request.session[:user_id] = 1
    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'
    assert_not_nil assigns(:contact)
    assert_equal Contact.find(1), assigns(:contact)
  end

  test "should put update" do
    @request.session[:user_id] = 1

    contact = Contact.find(1)
    old_firstname = contact.first_name
    new_firstname = 'Fist name modified by ContactsControllerTest#test_put_update'

    put :update, :id => 1, :project_id => 1, :contact => {:first_name => new_firstname}
    assert_redirected_to :action => 'show', :id => '1', :project_id => 1
    contact.reload
    assert_equal new_firstname, contact.first_name

  end

  test "should post destroy" do
    @request.session[:user_id] = 1
    post :destroy, :id => 1, :project_id => 'ecookbook'
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil Contact.find_by_id(1)
  end

  test "should bulk destroy contacts" do
    @request.session[:user_id] = 1

    post :bulk_destroy, :ids => [1, 2, 3]
    assert_redirected_to :controller => 'contacts', :action => 'index'

    assert_nil Contact.find_by_id(1, 2, 3)
  end

  test "should not bulk destroy contacts by deny user" do
    @request.session[:user_id] = 4
    assert_raises ActiveRecord::RecordNotFound do
      post :bulk_destroy, :ids => [1, 2]
    end

  end
  test "should get contacts notes" do
    # log_user('admin', 'admin')
    @request.session[:user_id] = 2

    get :contacts_notes
    assert_response :success
    assert_template :contacts_notes
    assert_select 'h2', /All notes/
    assert_select 'div#contacts_notes table.note_data div.note.content.preview', /Note 1/
  end

  test "should get context menu" do
    @request.session[:user_id] = 1
    xhr :get, :context_menu, :back_url => "/projects/contacts-plugin/contacts", :project_id => 'ecookbook', :ids => ['1', '2']
    assert_response :success
    assert_template 'context_menu'
  end

  test "should post index live search" do
    @request.session[:user_id] = 1
    xhr :post, :index, :search => "Domoway"
    assert_response :success
    assert_template '_list'
    assert_tag :tag => 'a', :content => /Domoway/
  end

  test "should post index live search in project" do
    @request.session[:user_id] = 1
    xhr :post, :index, :search => "Domoway", :project_id => 'ecookbook'
    assert_response :success
    assert_template '_list'
    assert_tag :tag => 'a', :content => /Domoway/
  end

  test "should post contacts_notes live search" do
    @request.session[:user_id] = 1
    xhr :post, :contacts_notes, :search_note => "Note 1"
    assert_response :success
    assert_template '_notes_list'
    assert_select 'table.note_data div.note.content.preview', /Note 1/
    assert_select 'table.note_data div.note.content.preview', {:count => 0, :text => /Note 2/}
  end

  test "should post contacts_notes live search in project" do
    @request.session[:user_id] = 1
    xhr :post, :contacts_notes, :search_note => "Note 2", :project_id => 'ecookbook'
    assert_response :success
    assert_template '_notes_list'
    assert_select 'table.note_data div.note.content.preview', /Note 2/
  end
end
