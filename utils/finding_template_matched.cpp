#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <boost/algorithm/string/split.hpp>
#include <boost/algorithm/string/classification.hpp>

using namespace std;
using namespace boost::algorithm;

#define LOG_NUM 4
#define ID 0
const char log_file_name[LOG_NUM][100] = { "/mnt/hdd0/data/hpc4/bgl2.log",
    "/mnt/hdd0/data/hpc4/liberty2.log",
    "/mnt/hdd0/data/hpc4/spirit2.log", 
    "/mnt/hdd0/data/hpc4/Thunderbird.log"};

const char template_file_name[LOG_NUM][100] = { "../data/string/bgl2_template.txt",
"../data/string/liberty2_template.txt",
"../data/string/spirit2_template.txt",
"../data/string/Thunderbird_template.txt"};

//20,44,87,103,140,176,186,193

int list_arr[LOG_NUM][8] = {
{9,21,28,34,48,53,70,90},
{20,44,87,103,140,176,186,193},
{8,44,60,90,122,148,181,224},
{2,13,30,61,77,84,101,120}};

int main(void)
{
    
    /* Template reading */
    for (int k = 0; k < 8; ++k) {

        ifstream in;
        in.open(template_file_name[ID]);

        string line;
        for (int i = 0; i < list_arr[ID][k]; ++i) {
            line = "";
            getline(in, line);
        }

        vector<string> template_data;
        split(template_data, line, is_any_of(" ")); // get template words

        ifstream df;
        df.open(log_file_name[ID]);
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
            }
            line_cnt++;
        }
        df.close();
        in.close();
    }
    return 0;
}
