require "json-schema"

class FormatRulesValidator < ActiveModel::EachValidator
  def validate(record)
    rules = record.criteria_rules
    unless JSON::Validator.validate(schema, rules)
      record.errors.add(:criteria_rules, '- incorrect format')
    end
  end

private

  def schema
    {
      "$schema" => "http://json-schema.org/draft-04/schema#",
      "type" => "array",
      "minItems" => 1,
      "items" => {
        "$ref" => "#/definitions/criteria"
      },
      "definitions" => {
        "criteria" => {
          "anyOf" => [
            {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[type key value],
              "properties" => {
                "type" => { "enum" => %w[tag] },
                "key" => { "type" => "string" },
                "value" => { "type" => "string" }
              }
            },
            {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[type key value],
              "properties" => {
                "type" => { "enum" => %w[link] },
                "key" => { "type" => "string" },
                "value" => {
                  "type" => "string",
                  "pattern" => "^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$"
                }
              }
            },
            {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[all_of],
              "properties" => {
                "all_of" => {
                  "type" => "array",
                  "items" => { "$ref" => "#/definitions/criteria" },
                  "minItems" => 1
                }
              }
            },
            {
              "type" => "object",
              "additionalProperties" => false,
              "required" => %w[any_of],
              "properties" => {
                "any_of" => {
                  "type" => "array",
                  "items" => { "$ref" => "#/definitions/criteria" },
                  "minItems" => 1
                }
              }
            }
          ]
        }
      }
    }
  end
end
