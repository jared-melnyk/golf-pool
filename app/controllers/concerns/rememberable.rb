# frozen_string_literal: true

module Rememberable
  extend ActiveSupport::Concern

  REMEMBER_COOKIE_EXPIRY = 1.year

  private

  def remember_user(user)
    raw_token = user.generate_remember_token
    remember_cookie_options = {
      expires: REMEMBER_COOKIE_EXPIRY.from_now,
      httponly: true,
      same_site: :lax
    }
    cookies.signed[:remember_user_id] = remember_cookie_options.merge(value: user.id)
    cookies.signed[:remember_token] = remember_cookie_options.merge(value: raw_token)
  end

  def forget_remember_user(user)
    user&.clear_remember_token!
    cookies.delete(:remember_user_id)
    cookies.delete(:remember_token)
  end

  def current_user_from_remember_cookie
    user_id = cookies.signed[:remember_user_id]
    raw_token = cookies.signed[:remember_token]
    return unless user_id.present? && raw_token.present?

    user = User.find_by(id: user_id)
    return unless user&.remember_token_valid?(raw_token)

    session[:user_id] = user.id
    remember_user(user)
    user
  end
end
