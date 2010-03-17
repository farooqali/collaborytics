module RepositoriesHelper
  def metric_value(selected_metric, checkins)
    Metric.send(selected_metric, checkins)
  end
end
