-- Allow audit_logs deletion during admin user purge (immutable trigger bypass)

CREATE OR REPLACE FUNCTION public.fn_prevent_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF COALESCE(current_setting('app.admin_purge', true), '') = 'true' THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'FORBIDDEN: Audit logs are immutable.';
END;
$$;
