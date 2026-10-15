class InterRecurringBillingJob < ApplicationJob
  queue_as :default

  def perform
    Inter::RecurringBilling.run_daily
  end
end
