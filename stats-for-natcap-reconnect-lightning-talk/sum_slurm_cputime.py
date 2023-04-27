import datetime
import fileinput

totaltime = datetime.timedelta()

# assume slurm file format is in one timestamp per line.
for line in fileinput.input():
    line = line.strip()
    try:
        days, hours_minutes_seconds = line.split('-')
    except ValueError:
        # When no '-', assume 0 days.
        days = 0
        hours_minutes_seconds = line

    try:
        hours, minutes, seconds = hours_minutes_seconds.split(':')
    except ValueError:
        hours = 0
        try:
            minutes, seconds = hours_minutes_seconds.split(':')
        except ValueError:
            print(hours_minutes_seconds)
            raise

    totaltime += datetime.timedelta(
        days=int(days),
        hours=int(hours),
        minutes=int(minutes),
        seconds=int(seconds))

print(totaltime)
