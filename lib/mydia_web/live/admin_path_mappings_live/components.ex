defmodule MydiaWeb.AdminPathMappingsLive.Components do
  @moduledoc false
  use MydiaWeb, :html

  alias Mydia.Settings

  attr :path_mappings, :list, required: true

  def path_mappings_tab(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-xl font-semibold">Path Mappings</h2>
          <p class="text-sm text-base-content/70">
            Translate paths reported by download clients into paths Mydia can see.
            The longest matching prefix wins.
          </p>
        </div>
        <button type="button" class="btn btn-primary btn-sm" phx-click="new_path_mapping">
          <.icon name="hero-plus" class="w-4 h-4" /> Add mapping
        </button>
      </div>

      <div :if={@path_mappings == []} id="path-mappings-empty" class="text-center py-10">
        <p class="text-base-content/60">No path mappings configured.</p>
        <p class="text-sm text-base-content/50 mt-1">
          Add one above, or set <code class="text-xs">PATH_MAPPING_N_REMOTE</code>
          / <code class="text-xs">PATH_MAPPING_N_LOCAL</code>
          environment variables.
        </p>
      </div>

      <ul :if={@path_mappings != []} id="path-mappings-list" class="list">
        <li :for={mapping <- @path_mappings} id={"mapping-#{mapping.id}"} class="list-row">
          <% is_runtime = Settings.runtime_config?(mapping) %>
          <div class="list-col-grow">
            <div class="font-mono text-sm break-all">
              {mapping.remote_prefix}
              <span class="opacity-50">→</span>
              {mapping.local_prefix}
            </div>
            <div :if={is_runtime} class="mt-1">
              <span
                class="badge badge-ghost badge-xs gap-1"
                title="Configured via environment variables (read-only)"
              >
                <.icon name="hero-lock-closed" class="w-3 h-3" /> ENV
              </span>
            </div>
          </div>
          <div class="flex gap-1">
            <button
              type="button"
              class="btn btn-square btn-ghost btn-sm"
              phx-click="edit_path_mapping"
              phx-value-id={mapping.id}
              disabled={is_runtime}
              title="Edit"
            >
              <.icon name="hero-pencil-square" class="size-4" />
            </button>
            <button
              type="button"
              class="btn btn-square btn-ghost btn-sm"
              phx-click="delete_path_mapping"
              phx-value-id={mapping.id}
              disabled={is_runtime}
              data-confirm="Delete this path mapping?"
              title="Delete"
            >
              <.icon name="hero-trash" class="size-4" />
            </button>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :mode, :atom, required: true

  def path_mapping_modal(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box">
        <h3 class="font-bold text-lg mb-4">
          {if @mode == :new, do: "Add path mapping", else: "Edit path mapping"}
        </h3>

        <.form
          for={@form}
          id="path-mapping-form"
          phx-change="validate_path_mapping"
          phx-submit="save_path_mapping"
        >
          <.input
            field={@form[:remote_prefix]}
            type="text"
            label="Remote prefix"
            placeholder="/downloads/complete"
          />
          <.input
            field={@form[:local_prefix]}
            type="text"
            label="Local prefix"
            placeholder="/data/torrents/complete"
          />

          <div class="modal-action">
            <button type="button" class="btn btn-ghost" phx-click="close_modal">Cancel</button>
            <button type="submit" class="btn btn-primary">Save</button>
          </div>
        </.form>
      </div>
      <div class="modal-backdrop" phx-click="close_modal"></div>
    </div>
    """
  end
end
