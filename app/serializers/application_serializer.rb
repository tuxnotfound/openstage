# Base for the JSON the page's scripts read (app/javascript/charts): each
# serializer lists its attributes in snake_case, and they leave camelCased.
class ApplicationSerializer
  def as_json(*)
    attributes.deep_transform_keys { |key| key.to_s.camelize(:lower) }
  end

  def to_json(*)
    as_json.to_json
  end
end
