require 'rails_helper'

RSpec.describe "Posts", type: :request do
  include ActiveSupport::Testing::TimeHelpers
  describe "GET /index" do
    let!(:matching_post) { create(:post, title: 'Visa renewal tips', body: 'Discuss ISSO paperwork') }
    let!(:non_matching_post) { create(:post, title: 'Dorm cooking', body: 'Best pans to buy') }

    it "redirects guests to the login page" do
      get posts_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "filters posts when a search term is present" do
      sign_in create(:user)

      get posts_path, params: { filters: { q: 'visa' } }

      expect(response.body).to include('Visa renewal tips')
      expect(response.body).not_to include('Dorm cooking')
    end

    it "shows an alert when the search term is blank" do
      sign_in create(:user)

      get posts_path, params: { filters: { q: '' } }

      expect(response.body).to include('Please enter text to search.')
      expect(response.body).to include('Post List')
    end
  end

  describe "GET /posts/my_threads" do
    let(:user) { create(:user) }
    let!(:owned_post) { create(:post, user: user, title: 'My housing post') }
    let!(:other_user_post) { create(:post, title: 'Someone else post') }

    it "redirects guests to the login page" do
      get my_threads_posts_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "shows only posts authored by the signed-in user" do
      sign_in user

      get my_threads_posts_path

      expect(response.body).to include('My Threads')
      expect(response.body).to include(owned_post.title)
      expect(response.body).not_to include(other_user_post.title)
    end

    it "applies search filters within the user's own threads" do
      additional_post = create(:post, user: user, title: 'Visa renewal checklist')
      sign_in user

      get my_threads_posts_path, params: { filters: { q: 'visa' } }

      expect(response.body).to include('Visa renewal checklist')
      expect(response.body).not_to include(owned_post.title)
      expect(response.body).not_to include(other_user_post.title)
    end
  end

  describe "POST /posts" do
    let(:user) { create(:user) }
    let(:topic) { create(:topic) }
    let(:tag) { create(:tag) }
    let(:valid_params) do
      {
        post: {
          title: 'Need visa advice',
          body: 'Looking for guidance on F-1 renewal.',
          topic_id: topic.id,
          tag_ids: [ tag.id ],
          school: Post::SCHOOLS.first,
          course_code: 'COMS W4152'
        }
      }
    end

    context "when signed in" do
      it "creates a new post" do
        sign_in user

        expect {
          post posts_path, params: valid_params
        }.to change(Post, :count).by(1)

        expect(response).to redirect_to(posts_path)
      end

      it "creates a thread identity for the author" do
        sign_in user

        expect {
          post posts_path, params: valid_params
        }.to change { ThreadIdentity.where(user: user).count }.by(1)
      end

      it "applies the expiration window when provided" do
        sign_in user
        params = valid_params.deep_dup
        params[:post][:expires_at] = '7'

        travel_to Time.zone.local(2024, 1, 1, 12, 0, 0) do
          post posts_path, params: params
        end

        created_post = Post.last
        expect(created_post.expires_at).to be_within(1.second).of(Time.zone.local(2024, 1, 8, 12, 0, 0))
      end

      it "treats zero-day expirations as no expiration" do
        sign_in user
        params = valid_params.deep_dup
        params[:post][:expires_at] = '0'

        expect {
          post posts_path, params: params
        }.to change(Post, :count).by(1)

        expect(Post.last.expires_at).to be_nil
      end

      it "treats negative expirations as no expiration" do
        sign_in user
        params = valid_params.deep_dup
        params[:post][:expires_at] = '-5'

        expect {
          post posts_path, params: params
        }.to change(Post, :count).by(1)

        expect(Post.last.expires_at).to be_nil
      end

      it "leaves expires_at nil when the field is blank" do
        sign_in user
        params = valid_params.deep_dup
        params[:post][:expires_at] = ''

        expect {
          post posts_path, params: params
        }.to change(Post, :count).by(1)

        expect(Post.last.expires_at).to be_nil
      end
    end

    context "when signed in with invalid data" do
      it "does not create post with missing title" do
        sign_in user

        invalid_params = valid_params.deep_dup
        invalid_params[:post][:title] = ""

        expect {
          post posts_path, params: invalid_params
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "does not create post with missing body" do
        sign_in user

        invalid_params = valid_params.deep_dup
        invalid_params[:post][:body] = ""

        expect {
          post posts_path, params: invalid_params
        }.not_to change(Post, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when not signed in" do
      it "redirects to the sign-in page" do
        post posts_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  if defined?(PostRevision)
    describe "PATCH /posts/:id" do
      let(:user) { create(:user) }
      let!(:post_record) { create(:post, user: user, title: 'Original Title', body: 'Original body text') }

      it "updates the post and records a revision" do
        sign_in user

        patch post_path(post_record), params: {
          post: {
            title: post_record.title,
            body: 'Updated body text',
            topic_id: post_record.topic_id,
            tag_ids: post_record.tag_ids,
            school: post_record.school,
            course_code: post_record.course_code
          }
        }

        expect(response).to redirect_to(post_path(post_record))
        expect(post_record.reload.body).to eq('Updated body text')
        expect(post_record.post_revisions.count).to eq(1)
        expect(post_record.post_revisions.first.title).to eq('Original Title')
      end

      it "prevents non-owners from editing" do
        sign_in create(:user)

        patch post_path(post_record), params: {
          post: {
            title: 'Unauthorized edit',
            body: 'Body',
            topic_id: post_record.topic_id,
            tag_ids: post_record.tag_ids
          }
        }

        expect(response).to redirect_to(post_path(post_record))
        expect(post_record.reload.title).to eq('Original Title')
      end
    end
  end

  describe "GET /posts/new" do
    let(:user) { create(:user) }

    it "renders the compose form" do
      sign_in user

      get new_post_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New Post')
    end
  end

  describe "POST /posts/preview" do
    let(:user) { create(:user) }
    let(:topic) { create(:topic) }
    let(:tag) { create(:tag) }

    it "renders the new template with preview content" do
      sign_in user

      post preview_posts_path, params: {
        post: {
          title: 'Preview title',
          body: 'Preview body',
          topic_id: topic.id,
          tag_ids: [ tag.id ],
          school: Post::SCHOOLS.first,
          course_code: 'COMS W4995'
        }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Draft Preview')
      expect(response.body).to include('Preview title')
    end
  end

  describe "GET /posts/:id" do
    let!(:post_record) { create(:post, :expiring_soon) }

    it "shows active posts" do
      sign_in post_record.user

      get post_path(post_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(post_record.title)
    end

    it "redirects expired posts back to the feed" do
      post_record.update_column(:expires_at, 1.day.ago)
      sign_in post_record.user

      get post_path(post_record)

      expect(response).to redirect_to(posts_path)
      follow_redirect!
      expect(response.body).to include('This post has expired.')
    end
  end

  describe "DELETE /posts/:id" do
    let!(:post_record) { create(:post) }

    context "when the post owner is signed in" do
      it "deletes the post" do
        sign_in post_record.user

        expect {
          delete post_path(post_record)
        }.to change(Post, :count).by(-1)

        expect(response).to redirect_to(posts_path)
        follow_redirect!
        expect(response.body).to include('Post deleted.')
      end
    end

    context "when a different user is signed in" do
      it "does not delete the post" do
        other_user = create(:user)
        sign_in other_user

        expect {
          delete post_path(post_record)
        }.not_to change(Post, :count)

        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('You do not have permission')
      end
    end

    context "when not signed in" do
      it "requires authentication" do
        delete post_path(post_record)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /posts/:id/reveal_identity" do
    let!(:post_record) { create(:post) }

    it "allows the author to reveal their identity" do
      sign_in post_record.user

      expect {
        patch reveal_identity_post_path(post_record)
      }.to change(AuditLog, :count).by(1)

      expect(post_record.reload.show_real_identity).to be(true)
      expect(response).to redirect_to(post_path(post_record))
      expect(AuditLog.last.metadata).to include('revealed_at')
    end

    it "prevents other users from revealing the identity" do
      other_user = create(:user)
      sign_in other_user

      expect {
        patch reveal_identity_post_path(post_record)
      }.not_to change(AuditLog, :count)

      expect(post_record.reload.show_real_identity).to be(false)
      expect(response).to redirect_to(post_path(post_record))
    end

    it "alerts the author when reveal fails" do
      sign_in post_record.user
      allow_any_instance_of(Post).to receive(:update).and_return(false)

      patch reveal_identity_post_path(post_record)

      expect(response).to redirect_to(post_path(post_record))
      follow_redirect!
      expect(response.body).to include('Unable to reveal identity.')
    end
  end

  describe "PATCH /posts/:id/unlock" do
    let!(:post_record) { create(:post) }

    it "reopens the thread when locked with an accepted answer" do
      answer = create(:answer, post: post_record)
      post_record.update!(locked_at: Time.current, accepted_answer: answer, status: Post::STATUSES[:solved])
      sign_in post_record.user

      patch unlock_post_path(post_record)

      expect(response).to redirect_to(post_path(post_record))
      follow_redirect!
      expect(response.body).to include('Thread reopened.')
      post_record.reload
      expect(post_record.locked?).to be(false)
      expect(post_record.accepted_answer).to be_nil
      expect(post_record.status).to eq(Post::STATUSES[:open])
    end

    it "alerts the user when unlock criteria are not met" do
      sign_in post_record.user

      patch unlock_post_path(post_record)

      expect(response).to redirect_to(post_path(post_record))
      follow_redirect!
      expect(response.body).to include('No accepted answer to unlock.')
    end
  end

  describe "PATCH /posts/:id/hide_identity" do
    let!(:post_record) { create(:post, show_real_identity: true) }

    context "when the author is signed in" do
      before { sign_in post_record.user }

      it "hides the author identity and logs the action" do
        expect {
          patch hide_identity_post_path(post_record)
        }.to change(AuditLog, :count).by(1)

        expect(post_record.reload.show_real_identity).to be(false)
        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('Your identity is now hidden on this thread.')
      end

      it "alerts the author when hide fails" do
        allow_any_instance_of(Post).to receive(:update).and_return(false)

        patch hide_identity_post_path(post_record)

        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('Unable to hide identity.')
      end
    end

    context "when a different user is signed in" do
      it "denies permission" do
        sign_in create(:user)

        patch hide_identity_post_path(post_record)

        expect(post_record.reload.show_real_identity).to be(true)
        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('You do not have permission to hide this identity.')
      end
    end
  end

  describe "POST /posts/:id/appeal" do
    let!(:post_record) { create(:post, ai_flagged: true) }

    context "when the author is signed in and post is ai_flagged" do
      before { sign_in post_record.user }

      it "submits the appeal successfully" do
        post appeal_post_path(post_record)

        expect(post_record.reload.appeal_requested).to be(true)
        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('Appeal submitted.')
      end
    end

    context "when the post is not ai_flagged" do
      let!(:unflagged_post) { create(:post, ai_flagged: false) }

      it "denies the appeal request" do
        sign_in unflagged_post.user

        post appeal_post_path(unflagged_post)

        expect(unflagged_post.reload.appeal_requested).to be(false)
        expect(response).to redirect_to(post_path(unflagged_post))
        follow_redirect!
        expect(response.body).to include('Unable to submit appeal.')
      end
    end

    context "when a different user is signed in" do
      it "denies the appeal request" do
        sign_in create(:user)

        post appeal_post_path(post_record)

        expect(post_record.reload.appeal_requested).to be(false)
        expect(response).to redirect_to(post_path(post_record))
        follow_redirect!
        expect(response.body).to include('Unable to submit appeal.')
      end
    end
  end

  describe "PATCH /posts/:id with invalid data" do
    let(:user) { create(:user) }
    let!(:post_record) { create(:post, user: user) }

    it "renders edit on validation failure" do
      sign_in user

      patch post_path(post_record), params: {
        post: {
          title: '',
          body: '',
          topic_id: post_record.topic_id,
          tag_ids: post_record.tag_ids
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
