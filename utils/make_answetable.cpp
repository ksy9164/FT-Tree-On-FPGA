#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <boost/algorithm/string/split.hpp>
#include <boost/algorithm/string/classification.hpp>

using namespace std;
using namespace boost::algorithm;

#define F_TABLE "../data/string/bgl2_hash.txt"
#define F_TEMPLATE "../data/string/bgl2_template.txt"

int hash_func1(std::string str){
    uint8_t idx = 0;
    for (int i = 0 ; i < str.size() ; ++i){
        uint8_t  temp = str[i];
        idx = idx ^ temp;
        idx = idx * 3;
    }
    return idx;
}

int hash_func2(std::string str){
    uint8_t idx = 23;
    for (int i = 0 ; i < str.size() ; ++i){
        uint8_t  temp = str[i];
        idx = idx ^ temp;
        idx = idx * 3;
    }
    return idx;
}

int main(void)
{

    /* Table upload */
    ifstream tf;
    /* tf.open("./data/hash_table.txt"); */
    tf.open(F_TABLE);

    string table[256];
    int i = 0;
    while (!tf.eof()) {
        string line;
        getline(tf, line);
        vector<string> token;
        split(token, line, is_any_of(" "));
        if (token.size() == 3) {
            table[i] = token[2];
        }
        i++;
    }

    /* Template reading */
    ifstream in;
    /* in.open("./data/bgl2.txt"); */
    in.open(F_TEMPLATE);

    int cnt = 1;
    while (!in.eof()) {
        string line;
        getline(in, line);
        vector<string> token;

        split(token, line, is_any_of(" "));
        uint8_t hash_a;
        uint8_t hash_b;
        if (cnt == 9 || cnt == 21 || cnt == 28 || cnt == 34 || cnt == 48 || cnt ==53 || cnt == 70 || cnt == 90) {
            cout << "\nTemplate No." << cnt << "\n\n";
            for (int i = 2; i < token.size(); i++) {
                hash_a = hash_func1(token[i]);
                hash_b = hash_func2(token[i]);
                string cmp;
                if (token[i].size() > 16) {
                    cmp = token[i].substr(0, 16);
                } else {
                    cmp = token[i];
                }

                uint8_t hash = 0;
                bool check = false;

                if (table[hash_a] == cmp) {
                    check = true;
                    hash = hash_a;
                } else if (table[hash_b] == cmp) {
                    check = true;
                    hash = hash_b;
                }

                if (check) {
                    cout << "\tanswer_t[" << (int)hash << "] = 1;" <<  endl;
                }
            }
        }

        cnt++;
    }

    return 0;
}
