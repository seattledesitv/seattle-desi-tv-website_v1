import { Resend } from "resend";
import { NextResponse } from "next/server";

const notifyTo = "seattledesitv@gmail.com";

type ContactPayload = {
  type?: "contact" | "crew_join" | "event_created" | "business_created" | "team_created" | "radio_team_created";
  name?: string;
  email?: string;
  phone?: string;
  interest?: string;
  message?: string;
  eventTitle?: string;
  eventId?: string;
  businessName?: string;
  teamName?: string;
  captchaToken?: string;
};

function escapeHtml(value: unknown) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

async function verifyTurnstile(captchaToken?: string) {
  if (!captchaToken) {
    return { success: false, error: "Captcha token is missing" };
  }

  if (!process.env.TURNSTILE_SECRET_KEY) {
    return { success: false, error: "TURNSTILE_SECRET_KEY is missing in Vercel" };
  }

  const verifyResponse = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      secret: process.env.TURNSTILE_SECRET_KEY,
      response: captchaToken,
    }),
  });

  return verifyResponse.json();
}

function buildEmail(payload: ContactPayload) {
  const type = payload.type || "contact";

  if (type === "crew_join") {
    return {
      subject: `Crew review needed: ${payload.name || payload.email || "New crew member"}`,
      html: `
        <h2>Desi TV Crew Join Request</h2>
        <p><b>User:</b> ${escapeHtml(payload.name || payload.email)}</p>
        <p><b>Email:</b> ${escapeHtml(payload.email)}</p>
        <p><b>Event:</b> ${escapeHtml(payload.eventTitle)}</p>
        <p><b>Event ID:</b> ${escapeHtml(payload.eventId)}</p>
        <p>Please review this crew self-selection in Supabase / Studio.</p>
      `,
    };
  }

  if (type === "event_created") {
    return {
      subject: `New Event Submitted: ${payload.eventTitle || "Untitled Event"}`,
      html: `
        <h2>New Event Submitted</h2>
        <p><b>Event:</b> ${escapeHtml(payload.eventTitle)}</p>
        <p><b>Submitted by:</b> ${escapeHtml(payload.email)}</p>
        <p>${escapeHtml(payload.message)}</p>
      `,
    };
  }

  if (type === "business_created") {
    return {
      subject: `New Business Submitted: ${payload.businessName || "Business"}`,
      html: `
        <h2>New Business Submitted</h2>
        <p><b>Business:</b> ${escapeHtml(payload.businessName)}</p>
        <p><b>Submitted by:</b> ${escapeHtml(payload.email)}</p>
        <p>${escapeHtml(payload.message)}</p>
      `,
    };
  }

  if (type === "team_created" || type === "radio_team_created") {
    return {
      subject: `New ${type === "team_created" ? "Team" : "Radio Team"} Member Added: ${payload.teamName || payload.name}`,
      html: `
        <h2>${type === "team_created" ? "Team" : "Radio Team"} Member Added</h2>
        <p><b>Name:</b> ${escapeHtml(payload.teamName || payload.name)}</p>
        <p><b>Submitted by:</b> ${escapeHtml(payload.email)}</p>
      `,
    };
  }

  return {
    subject: `New Contact Submission: ${payload.name || "Website Visitor"}`,
    html: `
      <h2>New Contact Submission</h2>
      <p><b>Name:</b> ${escapeHtml(payload.name)}</p>
      <p><b>Email:</b> ${escapeHtml(payload.email)}</p>
      <p><b>Phone:</b> ${escapeHtml(payload.phone)}</p>
      <p><b>Interest:</b> ${escapeHtml(payload.interest)}</p>
      <p><b>Message:</b></p>
      <p>${escapeHtml(payload.message)}</p>
    `,
  };
}

export async function POST(req: Request) {
  try {
    const payload = (await req.json()) as ContactPayload;
    const type = payload.type || "contact";

    // Public form submissions must pass captcha. Crew join emails are triggered after a logged-in DB action.
    if (type !== "crew_join") {
      const verifyData = await verifyTurnstile(payload.captchaToken);
      if (!verifyData.success) {
        return NextResponse.json(
          { success: false, error: "Captcha verification failed", details: verifyData },
          { status: 400 }
        );
      }
    }

    if (!process.env.RESEND_API_KEY) {
      return NextResponse.json(
        { success: false, step: "env_check", error: "RESEND_API_KEY is missing in Vercel" },
        { status: 500 }
      );
    }

    const resend = new Resend(process.env.RESEND_API_KEY);
    const email = buildEmail(payload);

    const result = await resend.emails.send({
      from: "Seattle Desi TV <onboarding@resend.dev>",
      to: notifyTo,
      replyTo: payload.email || undefined,
      subject: email.subject,
      html: email.html,
    });

    return NextResponse.json({ success: true, step: "email_sent", resendResult: result });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, step: "catch_error", error: error?.message || "Unknown error" },
      { status: 500 }
    );
  }
}
