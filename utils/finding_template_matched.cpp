#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <boost/algorithm/string/split.hpp>
#include <boost/algorithm/string/classification.hpp>

using namespace std;
using namespace boost::algorithm;

#define LOG_NUM 4

const char log_file_name[LOG_NUM][100] = { "/mnt/hdd0/data/hpc4/bgl2.log",
    "/mnt/hdd0/data/hpc4/liberty2.log",
    "/mnt/hdd0/data/hpc4/spirit2.log", 
    "/mnt/hdd0/data/hpc4/Thunderbird.log"};
//48,53,70,90
#define TABLE_FILE "../data/string/bgl2_template.txt"
#define TEMPLATE_NUM 90

int main(void)
{
    
    /* Template reading */
    ifstream in;
    in.open(TABLE_FILE);
    int template_number = TEMPLATE_NUM;

    string line;
    for (int i = 0; i < template_number; ++i) {
        line = "";
        getline(in, line);
    }

    vector<string> template_data;
    split(template_data, line, is_any_of(" ")); // get template words

    ifstream df;
    df.open(log_file_name[0]);
    int line_cnt = 0;
    while (!df.eof()) {
        string line;
        getline(df, line);
        int cnt = 0;
        for (int i = 2; i < template_data.size(); ++i) {
            if (line.find(template_data[i]) != std::string::npos) {
                cnt++;
            }
        }
        if (cnt >= template_data.size() - 2) {
            cout<< line << endl;
            /* cout << line_cnt << " " << line << endl; */
        }
        line_cnt++;
    }
    return 0;
}
