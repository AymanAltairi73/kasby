-- Notify sender on successful fund transfer (QR / P2P)

CREATE OR REPLACE FUNCTION public.create_transfer(
  p_amount numeric,
  p_receiver_referral_code text,
  p_transfer_type text DEFAULT 'funds'
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_sender_id       UUID := auth.uid();
  v_receiver_id     UUID;
  v_receiver_name   TEXT;
  v_sender_name     TEXT;
  v_sender_wallet   UUID;
  v_receiver_wallet UUID;
  v_sender_balance  NUMERIC;
  v_sender_points   NUMERIC;
  v_tx_id           UUID;
BEGIN
  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  SELECT id, full_name INTO v_receiver_id, v_receiver_name
    FROM profiles
    WHERE UPPER(referral_code) = UPPER(REPLACE(p_receiver_referral_code, '-', ''))
    LIMIT 1;

  IF v_receiver_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Receiver not found');
  END IF;

  IF v_receiver_id = v_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot transfer to yourself');
  END IF;

  SELECT full_name INTO v_sender_name FROM profiles WHERE id = v_sender_id LIMIT 1;

  IF p_transfer_type = 'funds' THEN
    SELECT id, available_balance INTO v_sender_wallet, v_sender_balance
      FROM wallets WHERE user_id = v_sender_id LIMIT 1;

    IF v_sender_balance < p_amount THEN
      RETURN json_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    SELECT id INTO v_receiver_wallet FROM wallets WHERE user_id = v_receiver_id LIMIT 1;

    UPDATE wallets SET available_balance = available_balance - p_amount
      WHERE id = v_sender_wallet;

    UPDATE wallets SET available_balance = available_balance + p_amount
      WHERE id = v_receiver_wallet;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency,
      status, counterpart_user_id, description
    ) VALUES (
      v_sender_id, v_sender_wallet, 'transfer_out', p_amount, 0, 'USD',
      'completed', v_receiver_id, 'تحويل إلى ' || v_receiver_name
    ) RETURNING id INTO v_tx_id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency,
      status, counterpart_user_id, description
    ) VALUES (
      v_receiver_id, v_receiver_wallet, 'transfer_in', p_amount, 0, 'USD',
      'completed', v_sender_id, 'تحويل واردة من ' || COALESCE(v_sender_name, 'مستخدم')
    );

    INSERT INTO notifications (user_id, title, message, type, status, sent_at)
    VALUES (
      v_receiver_id,
      'تم استلام تحويل',
      'تم تحويل مبلغ $' || p_amount || ' USD إليك من ' || COALESCE(v_sender_name, 'مستخدم'),
      'transfer_received', 'sent', NOW()
    );

    INSERT INTO notifications (user_id, title, message, type, status, sent_at)
    VALUES (
      v_sender_id,
      'تم إرسال التحويل',
      'تم تحويل $' || p_amount || ' USD إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
      'transfer_sent', 'sent', NOW()
    );

  ELSIF p_transfer_type = 'points' THEN
    SELECT current_balance INTO v_sender_points
      FROM user_points WHERE user_id = v_sender_id LIMIT 1;

    IF v_sender_points IS NULL OR v_sender_points < p_amount THEN
      RETURN json_build_object('success', false, 'error', 'Insufficient points');
    END IF;

    UPDATE user_points SET current_balance = current_balance - p_amount
      WHERE user_id = v_sender_id;

    INSERT INTO user_points (user_id, current_balance)
    VALUES (v_receiver_id, p_amount)
    ON CONFLICT (user_id) DO UPDATE
      SET current_balance = user_points.current_balance + EXCLUDED.current_balance;

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_sender_id, -p_amount, 'spend', 'تحويل نقاط إلى ' || v_receiver_name);

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_receiver_id, p_amount, 'earn', 'نقاط محوّلة من ' || COALESCE(v_sender_name, 'مستخدم'));

    SELECT gen_random_uuid() INTO v_tx_id;

    INSERT INTO notifications (user_id, title, message, type, status, sent_at)
    VALUES (
      v_receiver_id,
      'تم استلام نقاط',
      'تم تحويل ' || p_amount::INT || ' نقطة إليك من ' || COALESCE(v_sender_name, 'مستخدم'),
      'success', 'sent', NOW()
    );

    INSERT INTO notifications (user_id, title, message, type, status, sent_at)
    VALUES (
      v_sender_id,
      'تم إرسال النقاط',
      'تم تحويل ' || p_amount::INT || ' نقطة إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
      'success', 'sent', NOW()
    );
  END IF;

  RETURN json_build_object(
    'success',        true,
    'transaction_id', v_tx_id,
    'receiver_name',  v_receiver_name,
    'message',        'تم التحويل بنجاح'
  );
END;
$$;
