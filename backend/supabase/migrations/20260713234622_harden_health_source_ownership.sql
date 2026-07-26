-- Keep every health relationship inside the same user/provider boundary.
-- RLS remains the authorization layer; these constraints make the invariant
-- true for service-side writes and future clients as well.
alter table public.wearable_provider_connections
  add constraint wearable_connection_owner_provider_unique
  unique (connection_id, user_id, provider);

alter table public.health_data_sources
  add constraint health_source_owner_unique
  unique (source_id, user_id),
  add constraint health_source_owner_provider_unique
  unique (source_id, user_id, provider);

alter table public.health_data_sources
  add constraint health_source_connection_owner_fk
  foreign key (connection_id, user_id, provider)
  references public.wearable_provider_connections(
    connection_id, user_id, provider
  )
  on delete set null (connection_id);

alter table public.health_metric_records
  add constraint health_metric_source_owner_provider_fk
  foreign key (source_id, user_id, provider)
  references public.health_data_sources(source_id, user_id, provider)
  on delete cascade;

alter table public.health_source_preferences
  add constraint health_preference_source_owner_fk
  foreign key (source_id, user_id)
  references public.health_data_sources(source_id, user_id)
  on delete cascade;

-- The original single-column FK sets primary_source_id to null when a source
-- is removed. Deferring this ownership check lets that action complete first.
alter table public.match_health_summaries
  add constraint match_health_source_owner_fk
  foreign key (primary_source_id, user_id)
  references public.health_data_sources(source_id, user_id)
  deferrable initially deferred;
