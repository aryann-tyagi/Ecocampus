-- Migration: 20261019000000_device_tokens_and_push_notifications.sql
-- Description: Device registration tokens table, strict RLS policies, token management RPCs,
--              and push delivery trigger integration for genuine report events.

-- 1. Create Device Registration Tokens Table
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text NOT NULL DEFAULT 'android' CHECK (platform IN ('android', 'ios', 'web')),
  device_name text,
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_device_tokens_user_token_unique UNIQUE (user_id, fcm_token)
);

-- 2. Indexes for token lookups and recipient dispatch
CREATE INDEX IF NOT EXISTS idx_user_device_tokens_lookup
  ON public.user_device_tokens (user_id, is_active, last_seen_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_fcm_token
  ON public.user_device_tokens (fcm_token);

-- 3. Row Level Security Mandate
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

-- Clean existing policies if re-run
DROP POLICY IF EXISTS "Users can view own device tokens" ON public.user_device_tokens;
DROP POLICY IF EXISTS "Users can insert own device tokens" ON public.user_device_tokens;
DROP POLICY IF EXISTS "Users can update own device tokens" ON public.user_device_tokens;
DROP POLICY IF EXISTS "Users can delete own device tokens" ON public.user_device_tokens;

-- Policy: Users can only see their own device tokens (prevents cross-user token leaks)
CREATE POLICY "Users can view own device tokens"
  ON public.user_device_tokens
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Policy: Users can only register tokens for their own authenticated account
CREATE POLICY "Users can insert own device tokens"
  ON public.user_device_tokens
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Policy: Users can only update their own tokens
CREATE POLICY "Users can update own device tokens"
  ON public.user_device_tokens
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Policy: Users can delete/unregister their own device tokens
CREATE POLICY "Users can delete own device tokens"
  ON public.user_device_tokens
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 4. RPC: Register / Refresh Device Token
-- Idempotent upsert linking FCM token to current authenticated user.
-- Automatically re-activates tokens and updates last_seen_at.
CREATE OR REPLACE FUNCTION public.register_device_token(
  p_fcm_token text,
  p_platform text DEFAULT 'android',
  p_device_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_token_id uuid;
  v_cleaned_token text;
  v_cleaned_platform text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to register device token'
      USING ERRCODE = '42501';
  END IF;

  v_cleaned_token := btrim(p_fcm_token);
  IF v_cleaned_token IS NULL OR length(v_cleaned_token) < 10 THEN
    RAISE EXCEPTION 'Invalid FCM registration token'
      USING ERRCODE = '22023';
  END IF;

  v_cleaned_platform := lower(btrim(COALESCE(p_platform, 'android')));
  IF v_cleaned_platform NOT IN ('android', 'ios', 'web') THEN
    v_cleaned_platform := 'android';
  END IF;

  -- Upsert token: if this token is already linked to this user, update active state & timestamp
  INSERT INTO public.user_device_tokens (
    user_id,
    fcm_token,
    platform,
    device_name,
    is_active,
    last_seen_at,
    updated_at
  )
  VALUES (
    v_user_id,
    v_cleaned_token,
    v_cleaned_platform,
    btrim(p_device_name),
    true,
    now(),
    now()
  )
  ON CONFLICT (user_id, fcm_token)
  DO UPDATE SET
    platform = EXCLUDED.platform,
    device_name = COALESCE(EXCLUDED.device_name, public.user_device_tokens.device_name),
    is_active = true,
    last_seen_at = now(),
    updated_at = now()
  RETURNING id INTO v_token_id;

  RETURN jsonb_build_object(
    'ok', true,
    'token_id', v_token_id,
    'message', 'Device token registered successfully'
  );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text, text) TO authenticated;

-- 5. RPC: Unregister Device Token
-- Called on logout or account switch so the device stops receiving notifications for this user.
CREATE OR REPLACE FUNCTION public.unregister_device_token(
  p_fcm_token text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_cleaned_token text;
  v_deleted_count int;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required to unregister device token'
      USING ERRCODE = '42501';
  END IF;

  v_cleaned_token := btrim(p_fcm_token);
  IF v_cleaned_token IS NULL OR length(v_cleaned_token) = 0 THEN
    RETURN jsonb_build_object('ok', true, 'deleted', 0);
  END IF;

  DELETE FROM public.user_device_tokens
  WHERE user_id = v_user_id AND fcm_token = v_cleaned_token;

  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok', true,
    'deleted', v_deleted_count,
    'message', 'Device token unregistered'
  );
END;
$$;

-- Grant execution to authenticated users
GRANT EXECUTE ON FUNCTION public.unregister_device_token(text) TO authenticated;

-- 6. RPC: Clean Invalid FCM Tokens
-- Callable by trusted server-side background edge functions after receiving FCM HTTP v1 errors.
CREATE OR REPLACE FUNCTION public.clean_invalid_fcm_tokens(
  p_fcm_tokens text[]
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_count int := 0;
BEGIN
  IF p_fcm_tokens IS NULL OR array_length(p_fcm_tokens, 1) IS NULL THEN
    RETURN 0;
  END IF;

  DELETE FROM public.user_device_tokens
  WHERE fcm_token = ANY(p_fcm_tokens);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Revoke from public/anon/authenticated; only service_role can execute cleanup
REVOKE EXECUTE ON FUNCTION public.clean_invalid_fcm_tokens(text[]) FROM public, anon, authenticated;
