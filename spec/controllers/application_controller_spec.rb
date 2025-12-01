require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :authenticate_user!
    before_action :require_moderator!, only: :moderator_action
    before_action :require_staff!, only: :staff_action
    before_action :require_admin!, only: :admin_action

    def moderator_action
      head :ok
    end

    def staff_action
      head :ok
    end

    def admin_action
      head :ok
    end
  end

  let(:student) { create(:user) }
  let(:moderator) { create(:user, :moderator) }
  let(:staff) { create(:user, :staff) }
  let(:admin) { create(:user, :admin) }

  before do
    routes.draw do
      get 'moderator_action' => 'anonymous#moderator_action'
      get 'staff_action' => 'anonymous#staff_action'
      get 'admin_action' => 'anonymous#admin_action'
    end
  end

  describe '#require_moderator!' do
    it 'allows moderators and above' do
      allow(controller).to receive(:current_user).and_return(moderator)
      get :moderator_action
      expect(response).to have_http_status(:ok)
    end

    it 'redirects students' do
      allow(controller).to receive(:current_user).and_return(student)
      get :moderator_action
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Access denied. Moderator privileges required.')
    end
  end

  describe '#require_staff!' do
    it 'allows staff' do
      allow(controller).to receive(:current_user).and_return(staff)
      get :staff_action
      expect(response).to have_http_status(:ok)
    end

    it 'allows admin (admin? branch)' do
      allow(controller).to receive(:current_user).and_return(admin)
      get :staff_action
      expect(response).to have_http_status(:ok)
    end

    it 'blocks moderators' do
      allow(controller).to receive(:current_user).and_return(moderator)
      get :staff_action
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Access denied. Staff privileges required.')
    end
  end

  describe '#require_admin!' do
    it 'allows admins' do
      allow(controller).to receive(:current_user).and_return(admin)
      get :admin_action
      expect(response).to have_http_status(:ok)
    end

    it 'blocks staff' do
      allow(controller).to receive(:current_user).and_return(staff)
      get :admin_action
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Access denied. Administrator privileges required.')
    end
  end
end
