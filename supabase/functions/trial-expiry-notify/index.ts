// trial-expiry-notify: Emails users whose free trial is ending (≤3 days) or
// has ended, then records each send in trial_notify_log (dedupe).
//
// Uses SMTP (nodemailer) instead of Resend.
//
// Deploy: supabase functions deploy trial-expiry-notify
// Env:
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM, NOTIFY_SECRET
// Cron:  supabase cron schedule "trial-expiry-daily" "0 9 * * *" trial-expiry-notify
//        (daily 9 AM IST)
//
// Test:  curl -X POST -H "Authorization: Bearer <any-key>"
//          https://<project>.functions.supabase.co/trial-expiry-notify
// Test email: curl -X POST -H "x-notify-secret: <secret>" \
//          -d '{"test_email":"someone@example.com"}' \
//          https://<project>.functions.supabase.co/trial-expiry-notify
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.14";

const SMTP_HOST = Deno.env.get("SMTP_HOST") ?? "";
const SMTP_PORT = Number(Deno.env.get("SMTP_PORT") ?? "587");
const SMTP_USER = Deno.env.get("SMTP_USER") ?? "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") ?? "";
const SMTP_FROM =
  Deno.env.get("SMTP_FROM") ?? "PowerEMS <sells.brilliants.in@gmail.com>";
const NOTIFY_SECRET = Deno.env.get("NOTIFY_SECRET") ?? "";

const transporter = nodemailer.createTransport({
  host: SMTP_HOST,
  port: SMTP_PORT,
  secure: SMTP_PORT === 465,
  auth: { user: SMTP_USER, pass: SMTP_PASS },
});

function planCtaUrl(): string {
  return "https://app.brilliants.in/";
}

function buildHtml(kind: "upcoming" | "expired", daysLeft: number, trialEnd: string): string {
  const accent = kind === "upcoming" ? "#F59E0B" : "#DC2626";
  const emoji = kind === "upcoming" ? "&#9201;&#65039;" : "&#128720;";
  const title = kind === "upcoming"
    ? "Your free trial is ending soon"
    : "Your free trial has ended";
  const message = kind === "upcoming"
    ? `<strong>${daysLeft} day${daysLeft === 1 ? "" : "s"} left</strong> — your PowerEMS free trial ends on ` +
      `<strong>${trialEnd}</strong>. Add a plan before then to keep your meters and readings unlocked.`
    : "Your PowerEMS free trial ended. New readings and meters are now locked. " +
      "Subscribe to a plan to continue managing your energy data.";

  return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:24px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.1);">
        <tr><td style="background:${accent};padding:20px 24px;">
          <span style="font-size:24px;">${emoji}</span>
          <span style="color:#fff;font-size:18px;font-weight:700;margin-left:8px;">${title}</span>
        </td></tr>
        <tr><td style="padding:24px;">
          <p style="font-size:14px;color:#374151;line-height:1.6;margin:0 0 16px;">Hi,</p>
          <p style="font-size:14px;color:#374151;line-height:1.6;margin:0 0 16px;">${message}</p>
          <table width="100%" cellpadding="0" cellspacing="0" style="background:#F9FAFB;border-radius:8px;padding:12px 16px;margin:0 0 20px;">
            <tr><td style="font-size:12px;color:#6B7280;">
              Plan options: <strong>Starter ₹999/mo</strong> &bull; <strong>Growth ₹2,500/mo</strong> &bull; <strong>Pro ₹5,000/mo</strong>
            </td></tr>
          </table>
        </td></tr>
        <tr><td style="padding:0 24px 24px;">
          <a href="${planCtaUrl()}"
             style="display:inline-block;background:#3B82F6;color:#fff;padding:10px 20px;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">
            Choose a Plan
          </a>
        </td></tr>
        <tr><td style="padding:12px 24px;background:#F9FAFB;border-top:1px solid #E5E7EB;">
          <p style="font-size:11px;color:#9CA3AF;margin:0;">PowerEMS &mdash; Energy Management System</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

serve(async (req) => {
  try {
    // Caller check: any Supabase key (cron posts one) OR the notify secret.
    const secret = req.headers.get("x-notify-secret") ?? "";
    const hasAuth = (req.headers.get("Authorization")?.length ?? 0) > 0;
    const hasApiKey = (req.headers.get("apikey")?.length ?? 0) > 0;
    if (!(secret === NOTIFY_SECRET && secret.length > 0) && !hasAuth && !hasApiKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    let body: Record<string, unknown> = {};
    try {
      const parsed = await req.json();
      if (parsed && typeof parsed === "object") body = parsed as Record<string, unknown>;
    } catch {
      // ignore empty body
    }

    // Test path: send one email to a given address (guarded by secret).
    if (typeof body.test_email === "string" && body.test_email.length > 0) {
      if (secret !== NOTIFY_SECRET || secret.length === 0) {
        return new Response(JSON.stringify({ error: "forbidden" }), { status: 403 });
      }
      const info = await transporter.sendMail({
        from: SMTP_FROM,
        to: [body.test_email],
        subject: "[PowerEMS] SMTP test — trial-expiry pipeline",
        html: buildHtml(
          "upcoming",
          3,
          new Date(Date.now() + 3 * 86400000).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }),
        ),
      });
      return new Response(JSON.stringify({ success: true, test_email: body.test_email, messageId: info.messageId }));
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { data: recipients, error } = await supabase.rpc("get_trial_expiry_recipients");
    if (error) {
      console.error("RPC error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    const list = (recipients ?? []) as Array<{
      user_id: string;
      email: string;
      trial_end: string;
      notify_type: "upcoming" | "expired";
      days_left: number;
    }>;

    const upcoming = list.filter((r) => r.notify_type === "upcoming");
    const expired = list.filter((r) => r.notify_type === "expired");

    if (upcoming.length + expired.length === 0) {
      return new Response(JSON.stringify({ success: true, upcoming: 0, expired: 0, total: 0 }));
    }

    const results: Array<{ email: string; notify_type: string; ok: boolean; error?: string }> = [];

    for (const r of list) {
      const trialEnd = new Date(r.trial_end).toLocaleDateString("en-IN", {
        timeZone: "Asia/Kolkata",
        weekday: "short",
        day: "2-digit",
        month: "short",
        year: "numeric",
      });
      try {
        const info = await transporter.sendMail({
          from: SMTP_FROM,
          to: [r.email],
          subject: r.notify_type === "upcoming"
            ? `[PowerEMS] Your free trial ends in ${r.days_left} day${r.days_left === 1 ? "" : "s"}`
            : "[PowerEMS] Your free trial has ended",
          html: buildHtml(r.notify_type, r.days_left, trialEnd),
        });

        await supabase.from("trial_notify_log").insert({
          user_id: r.user_id,
          notify_type: r.notify_type,
          trial_end: r.trial_end,
        });

        results.push({ email: r.email, notify_type: r.notify_type, ok: true });
        console.log(`Sent ${r.notify_type} email to ${r.email} (${info.messageId})`);
      } catch (e) {
        const err = e instanceof Error ? e.message : String(e);
        console.error(`SMTP error for ${r.email}:`, err);
        results.push({ email: r.email, notify_type: r.notify_type, ok: false, error: err });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      upcoming: upcoming.length,
      expired: expired.length,
      total: list.length,
      sent: results.filter((x) => x.ok).length,
      failed: results.filter((x) => !x.ok).length,
      results,
    }));
  } catch (e) {
    console.error("trial-expiry-notify error:", e);
    return new Response(JSON.stringify({ error: "Internal error" }), { status: 500 });
  }
});