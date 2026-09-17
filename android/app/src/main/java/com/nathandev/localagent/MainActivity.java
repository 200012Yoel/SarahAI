package com.nathandev.localagent;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

public final class MainActivity extends Activity {

    private SarahEngine engine;
    private LinearLayout conversation;
    private EditText input;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        engine = new SarahEngine(this);
        setContentView(buildUi());
        addAssistantMessage("Sarah Android est prête.\n\n" + engine.getDeviceSummary());
    }

    private View buildUi() {
        final int pad = dp(14);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(pad, pad, pad, pad);
        root.setBackgroundColor(Color.rgb(17, 18, 22));

        TextView title = new TextView(this);
        title.setText("Local agent • Sarah");
        title.setTextColor(Color.WHITE);
        title.setTextSize(24);
        title.setGravity(Gravity.CENTER_VERTICAL);
        root.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        TextView subtitle = new TextView(this);
        subtitle.setText("Moteur " + engine.getDeviceMode().name() + " • build Android test");
        subtitle.setTextColor(Color.rgb(170, 176, 190));
        subtitle.setTextSize(13);
        subtitle.setPadding(0, dp(4), 0, dp(12));
        root.addView(subtitle);

        final ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        conversation = new LinearLayout(this);
        conversation.setOrientation(LinearLayout.VERTICAL);
        conversation.setPadding(0, 0, 0, dp(8));
        scroll.addView(conversation, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        root.addView(scroll, scrollParams);

        LinearLayout composer = new LinearLayout(this);
        composer.setOrientation(LinearLayout.HORIZONTAL);
        composer.setGravity(Gravity.CENTER_VERTICAL);

        input = new EditText(this);
        input.setHint("Écris à Sarah…");
        input.setHintTextColor(Color.rgb(130, 136, 150));
        input.setTextColor(Color.WHITE);
        input.setSingleLine(false);
        input.setMaxLines(4);
        input.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES | InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        input.setBackgroundColor(Color.rgb(38, 41, 48));
        input.setPadding(dp(12), dp(10), dp(12), dp(10));
        composer.addView(input, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));

        Button send = new Button(this);
        send.setText("Envoyer");
        LinearLayout.LayoutParams sendParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        sendParams.leftMargin = dp(8);
        composer.addView(send, sendParams);

        send.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                sendCurrentMessage(scroll);
            }
        });

        root.addView(composer, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        return root;
    }

    private void sendCurrentMessage(final ScrollView scroll) {
        String text = input.getText().toString().trim();
        if (text.length() == 0) {
            return;
        }
        input.setText("");
        addUserMessage(text);
        addAssistantMessage(engine.reply(text));
        scroll.post(new Runnable() {
            @Override
            public void run() {
                scroll.fullScroll(View.FOCUS_DOWN);
            }
        });
    }

    private void addUserMessage(String text) {
        TextView view = messageView("Toi\n" + text, Color.rgb(216, 228, 255), Color.rgb(34, 70, 135));
        LinearLayout.LayoutParams params = messageParams();
        params.gravity = Gravity.RIGHT;
        conversation.addView(view, params);
    }

    private void addAssistantMessage(String text) {
        TextView view = messageView("Sarah\n" + text, Color.WHITE, Color.rgb(44, 47, 56));
        LinearLayout.LayoutParams params = messageParams();
        params.gravity = Gravity.LEFT;
        conversation.addView(view, params);
    }

    private TextView messageView(String text, int textColor, int backgroundColor) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextColor(textColor);
        view.setTextSize(16);
        view.setBackgroundColor(backgroundColor);
        view.setPadding(dp(12), dp(10), dp(12), dp(10));
        return view;
    }

    private LinearLayout.LayoutParams messageParams() {
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(0, dp(6), 0, dp(6));
        return params;
    }

    private int dp(int value) {
        float density = getResources().getDisplayMetrics().density;
        return (int) (value * density + 0.5f);
    }
}
