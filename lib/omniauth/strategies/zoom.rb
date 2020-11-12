# frozen_string_literal: true

require 'base64'
require 'oauth2'
require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    # OmniAuth strategy for zoom.us
    class Zoom < OmniAuth::Strategies::OAuth2
      option :name, 'zoom'
      option :client_options, site: 'https://zoom.us'

      uid { raw_info['id'] }
      info do
        {
          name: [raw_info['first_name'], raw_info['last_name']].compact.join(' '),
          email: raw_info['email'],
          nickname: '',
          first_name: raw_info['first_name'],
          last_name: raw_info['last_name'],
          location: '',
          description: '',
          image: raw_info['pic_url'],
          phone: '',
          urls: {
            'personal_meeting_url' => raw_info['personal_meeting_url']
          }
        }
      end
      extra do
        {
          raw_info: raw_info
        }
      end

    protected

      def build_access_token
        params = {
          grant_type: 'authorization_code',
          code: request.params['code'],
          redirect_uri: callback_url
        }
        path = "#{client.options[:token_url]}?#{URI.encode_www_form(params)}"
        headers_secret = Base64.strict_encode64("#{client.id}:#{client.secret}")
        opts = {headers: {Authorization: "Basic #{headers_secret}"}}

        res = client.request(:post, path, opts)
        ::OAuth2::AccessToken.from_hash(client, res.parsed)
      end

    private

      def raw_info
        return @raw_info if defined?(@raw_info)

        @raw_info = access_token.get('/v2/users/me').parsed || {}
      rescue ::OAuth2::Error => e
        raise e unless e.response.status == 400

        # in case of missing a scope for reading current user info
        log(:error, "#{e.class} occured. message:#{e.message}")
        @raw_info = {}
      end

      def callback_url
        options[:redirect_uri] || (full_host + script_name + callback_path)
      end
    end
  end
end
