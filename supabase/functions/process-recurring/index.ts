import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data, error } = await supabase.rpc("process_due_recurring_investments");

    if (error) throw error;

    // Send notifications for processed investments
    const processed = data?.results || [];
    for (const item of processed) {
      if (item.result?.success) {
        await supabase.from("notifications").insert({
          user_id: item.result?.investment_result?.user_id,
          title: "Recurring Investment Executed",
          message: `Your scheduled investment has been executed successfully.`,
          type: "financial",
          entity_type: "investment",
        });
      }
    }

    return new Response(JSON.stringify(data), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { "Content-Type": "application/json" },
      status: 500,
    });
  }
});
