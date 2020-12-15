#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <boost/algorithm/string/split.hpp>
#include <boost/algorithm/string/classification.hpp>

using namespace std;
using namespace boost::algorithm;

uint8_t rand_generator(uint8_t old_rand) {
    uint8_t a = 133;
    uint8_t b = 237;
    uint8_t c = 255;
    return (uint8_t)((uint8_t)((uint8_t)(a*old_rand) + b) % c);
}

int hash_func1(string str){
    uint8_t idx = 0;
    uint8_t temp;
    for (auto c : str){
        temp = (uint8_t)c;
        idx = (uint8_t)((uint8_t)((uint8_t)(idx ^ temp) * (uint8_t)(idx + temp)) + idx);
    }
    return idx;
}

int hash_func2(string str){
    uint8_t rd,idx,temp;
    idx = 33;
    for (auto c : str){
        temp = (uint8_t)c;
        rd = rand_generator(idx);
        idx = (uint8_t)((uint8_t)(idx ^ (uint8_t)(temp + rd)) * rd);
    }
    return idx;
}

int main(void)
{

    /* Table upload */
    ifstream tf;
    tf.open("hash_table.txt");

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
    in.open("bgl2.txt");

    int cnt = 1;
    while (!in.eof()) {
        string line;
        getline(in, line);
        vector<string> token;

        split(token, line, is_any_of(" "));
        uint8_t hash_a;
        uint8_t hash_b;
        if (cnt == 9 || cnt == 21 || cnt == 28 || cnt == 34) {
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
                    cout << "answer_t[" << (int)hash << "] = 1;" <<  endl;
                }
            }
        }

        cnt++;
    }

    return 0;
}
