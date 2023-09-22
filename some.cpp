#include <wx/wx.h>
#include <wx/timer.h>
#include <fstream>
#include <sstream>
#include <string>

class MyFrame : public wxFrame {
public:
    MyFrame(const wxString& title)
        : wxFrame(NULL, wxID_ANY, title, wxDefaultPosition, wxSize(400, 200)) {
        // Create GUI elements
        panel = new wxPanel(this);
        dateLabel = new wxStaticText(panel, wxID_ANY, "System Date:");
        timeLabel = new wxStaticText(panel, wxID_ANY, "System Time:");
        cpuLabel = new wxStaticText(panel, wxID_ANY, "CPU Usage:");
        timestampLabel = new wxStaticText(panel, wxID_ANY, "Timestamp:");

        // Create a timer that updates the information every 100 milliseconds
        timer = new wxTimer(this, wxID_ANY);
        Bind(wxEVT_TIMER, &MyFrame::OnTimer, this);
        timer->Start(100);

        // Set up sizers for layout
        wxBoxSizer* vBox = new wxBoxSizer(wxVERTICAL);
        vBox->Add(dateLabel, 0, wxALL, 10);
        vBox->Add(timeLabel, 0, wxALL, 10);
        vBox->Add(cpuLabel, 0, wxALL, 10);
        vBox->Add(timestampLabel, 0, wxALL, 10);
        panel->SetSizer(vBox);
    }

    void OnTimer(wxTimerEvent& event) {
        // Get and update system date and time
        wxDateTime now = wxDateTime::Now();
        wxString timestamp = now.Format("%Y-%m-%dT%H:%M:%S.%l");

        // Update labels
        dateLabel->SetLabel(wxString::Format("System Date: %s", now.FormatISODate()));
        timeLabel->SetLabel(wxString::Format("System Time: %s", now.FormatISOTime()));
        timestampLabel->SetLabel(wxString::Format("Timestamp: %s", timestamp));
        
        // Get and update CPU usage
        float cpuUsage = GetCPUUsage();
        cpuLabel->SetLabel(wxString::Format("CPU Usage: %.2f%%", cpuUsage));
    }


    float GetCPUUsage() {
        std::ifstream statFile("/proc/stat");
        std::string line;

        if (std::getline(statFile, line)) {
            std::istringstream iss(line);
            std::string cpuLabel;
            int user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice;
            
            iss >> cpuLabel >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal >> guest >> guest_nice;
            
            // Calculate CPU usage as a percentage
            int totalCpuTime = user + nice + system + idle + iowait + irq + softirq + steal;
            int idleTime = idle + iowait;
            int nonIdleTime = user + nice + system + irq + softirq + steal + guest + guest_nice;
            
            float cpuUsage = 100.0 * (1.0 - static_cast<float>(idleTime) / totalCpuTime);
            return cpuUsage;
        }
        
        return 0.0;
    }

private:
    wxPanel* panel;
    wxStaticText* dateLabel;
    wxStaticText* timeLabel;
    wxStaticText* cpuLabel;
    wxStaticText* timestampLabel;
    wxTimer* timer;
};

class MyApp : public wxApp {
public:
    virtual bool OnInit() {
        MyFrame* frame = new MyFrame("System Info");
        frame->Show(true);
        return true;
    }
};

wxIMPLEMENT_APP(MyApp);


