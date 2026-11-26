"""Render matching app and widget signing options from build environment."""
import os
from pathlib import Path
import plistlib
import sys

data = plistlib.loads(Path(__file__).with_name("ExportOptions.plist").read_bytes())
data["teamID"] = os.environ["TEAM_ID"]
app_id = os.environ.get("APP_ID", "com.hgsldswk.dopaminemenu")
data["provisioningProfiles"] = {
    app_id: os.environ.get("APP_PROFILE", "DopamineMenu AppStore"),
    f"{app_id}.widget": os.environ.get("WIDGET_PROFILE", "DopamineMenu Widget AppStore"),
}
sys.stdout.buffer.write(plistlib.dumps(data))
