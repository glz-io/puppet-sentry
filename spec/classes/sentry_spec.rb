require 'spec_helper'

describe 'Sentry' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts.merge({
            python_version: '2.7.5',
            })
        end
        context 'all default values' do
          it { is_expected.to contain_class('sentry::setup') }
          it { is_expected.to contain_class('sentry::config') }
          it { is_expected.to contain_class('sentry::install') }
          it { is_expected.to contain_class('sentry::service') }
          it { is_expected.to contain_class('sentry::wsgi') }
        end

        context 'Sentry version < 8.5.0' do
          let (:params) {{ :version => '8.4.0' }}
          it "should fail" do
            expect { catalogue }.to raise_error(Puppet::Error, /Sentry version 8.5.0 or greater is required./)
          end
        end
      end
    end
  end
end
