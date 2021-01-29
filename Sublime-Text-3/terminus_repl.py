import sublime
import sublime_plugin


def _terminus_view(window, tagName):
    window = window or sublime.active_window()
    for view in window.views():
        if view.settings().get("terminus_view.tag") == tagName:
            return view

    return None


class SendSelectionToTerminusCommand(sublime_plugin.WindowCommand):
    def run(self, tag=None, visible_only=False):
        view = self.window.active_view()
        if view == None:
            return

        if any(sel.empty() for sel in view.sel()):
            spans = [sublime.Region(0, len(view))]
        else:
            spans = [sel for sel in view.sel() if not sel.empty()]

        for span in spans:
            self.window.run_command("terminus_send_string", {
                "string": view.substr(span),
                "tag": tag,
                "visible_only": visible_only
                })


class SampleREPLListener(sublime_plugin.EventListener):
    def on_query_context(self, view, key, operator, operand, match_all):
        if key == "terminus_tag.exists" or key == "terminus_tag.notexists":
            view = _terminus_view(view.window(), operand)
            return view != None if key == "terminus_tag.exists" else view == None

        return None
