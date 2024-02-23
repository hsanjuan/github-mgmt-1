locals {
  organization      = terraform.workspace
  resource_types    = []
  advanced_security = false
  config            = yamldecode(file("${path.module}/../github/${local.organization}.yml"))
  state             = jsondecode(file("${path.module}/${local.organization}.tfstate.json"))
  resources = {
    "config" = {
      "github_membership" = {
        "this" = {
          for item in flatten([
            for role, members in lookup(local.config, "members", {}) : [
              for member in members : {
                username = member
                role     = role
              }
            ]
          ]) : lower("${item.username}") => item
        }
      }
      "github_repository" = {
        "this" = {
          for item in [
            for repository, config in lookup(local.config, "repositories", {}) : merge(config, {
              name = repository
              security_and_analysis = (try(config.visibility, "private") == "public" || local.advanced_security) ? [
                {
                  advanced_security               = try(config.visibility, "private") == "public" || !local.advanced_security ? [] : [{ "status" : try(config.advanced_security, false) ? "enabled" : "disabled" }]
                  secret_scanning                 = try(config.visibility, "private") != "public" ? [] : [{ "status" : try(config.secret_scanning, false) ? "enabled" : "disabled" }]
                  secret_scanning_push_protection = try(config.visibility, "private") != "public" ? [] : [{ "status" : try(config.secret_scanning_push_protection, false) ? "enabled" : "disabled" }]
              }] : []
              pages = try(config.pages, null) != null ? [
                {
                  cname = try(config.pages.cname, null)
                  source = try(config.pages.source, null) == null ? [] : [
                    {
                      branch = config.pages.source.branch
                      path   = try(config.pages.source.path, null)
                    }
                  ]
              }] : []
              template = try([config.template], [])
            })
          ] : lower("${item.name}") => item
        }
      }
      "github_repository_collaborator" = {
        "this" = {
          for item in flatten([
            for repository, config in lookup(local.config, "repositories", {}) : flatten([
              for permission, members in lookup(config, "collaborators", {}) : [
                for member in members : {
                  repository = repository
                  username   = member
                  permission = permission
                }
              ]
            ])
          ]) : lower("${item.repository}:${item.username}") => item
        }
      }
      "github_branch_protection" = {
        "this" = {
          for item in flatten([
            for repository, config in lookup(local.config, "repositories", {}) : [
              for pattern, config in lookup(config, "branch_protection", {}) : merge(config, {
                pattern                       = pattern
                repository                    = repository
                required_pull_request_reviews = try([config.required_pull_request_reviews], [])
                required_status_checks        = try([config.required_status_checks], [])
              })
            ]
          ]) : lower("${item.repository}:${item.pattern}") => item
        }
      }
      "github_team" = {
        "this" = {
          for item in [for team, config in lookup(local.config, "teams", {}) : merge(config, {
            name = team
          })] : lower("${item.name}") => item
        }
      }
      "github_team_repository" = {
        "this" = {
          for item in flatten([
            for repository, config in lookup(local.config, "repositories", {}) : flatten([
              for permission, teams in lookup(config, "teams", {}) : [
                for team in teams : {
                  repository = repository
                  team       = team
                  permission = permission
                }
              ]
            ])
          ]) : lower("${item.team}:${item.repository}") => item
        }
      }
      "github_team_membership" = {
        "this" = {
          for item in flatten([
            for team, config in lookup(local.config, "teams", {}) : flatten([
              for role, members in lookup(config, "members", {}) : [
                for member in members : {
                  team     = team
                  username = member
                  role     = role
                }
              ]
            ])
          ]) : lower("${item.team}:${item.username}") => item
        }
      }
      "github_repository_file" = {
        "this" = {
          for item in flatten([
            for repository, config in lookup(local.config, "repositories", {}) : [
              for file, config in lookup(config, "files", {}) : merge(config, {
                repository = repository
                file       = file
                content    = try(file("${path.module}/../files/${config.content}"), config.content)
              })
            ]
          ]) : lower("${item.repository}/${item.file}") => item
        }
      }
      "github_issue_label" = {
        "this" = {
          for item in flatten([
            for repository, config in lookup(local.config, "repositories", {}) : [
              for label, config in lookup(config, "labels", {}) : merge(config, {
                repository = repository
                label      = label
              })
            ]
          ]) : lower("${item.repository}:${item.label}") => item
        }
      }
    }
    "state" = {
      for mode, item in {
        for item in local.state.values.root_module.resources : item.mode => item...
        } : mode => {
        for type, item in {
          for item in item : item.type => item...
          } : type => {
          for name, item in {
            for item in item : item.name => item...
            } : name => {
            for index, item in {
              for item in item : item.index => item.values
            } : index => item
          }
        }
      }
    }.managed
  }
}
