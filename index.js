const username = process.env.WEB_USERNAME || "admin";
const password = process.env.WEB_PASSWORD || "password";
const projectPageURL = process.env.URL || `https://www.google.com`;// 替换为你的项目域名
const intervalInMilliseconds = process.env.TIME || 2 * 60 * 1000; // 自动访问间隔时间
const port = process.env.PORT || 3000;
const express = require("express");
const app = express();
const exec = require("child_process").exec;
const fs = require("fs");
const path = require("path");
const auth = require("basic-auth");
const axios = require('axios');
const os = require('os');

app.get("/", function(req, res) {
  res.send("hello world");
});

// 读取list和sub文件
app.get("/list", (req, res) => {
  const user = auth(req);
  if (
    user &&
    user.name === username &&
    user.pass === password
  ) {
    fs.readFile("list.txt", "utf8", (err, data) => {
      if (err) {
        console.error(err);
        res.status(500).json({ error: "Error reading list.txt" });
      } else {
        res.status(200).send(data);
      }
    });
  } else {
    res.set("WWW-Authenticate", 'Basic realm="Node"');
    res.status(401).send("Unauthorized");
  }
});
app.get("/sub", (req, res) => {
  fs.readFile("sub.txt", "utf8", (err, data) => {
    if (err) {
      console.error(err);
      res.status(500).json({ error: "Error reading sub.txt" });
    } else {
      res.setHeader('Content-Type', 'application/octet-stream');
      res.status(200).send(data);
    }
  });
});

// 判断系统架构
function getSystemArchitecture() {
  const arch = os.arch();
  if (arch === 'arm' || arch === 'arm64') {
    return 'arm';
  } else {
    return 'amd';
  }
}

// 下载必要运行文件
function downloadFile(fileName, fileUrl, callback) {
  axios({
    method: 'get',
    url: fileUrl,
    responseType: 'stream',
  })
    .then(response => {
      const stream = fs.createWriteStream(path.join('./', fileName));
      response.data.pipe(stream);
      stream.on('finish', function() {
        stream.close();
        callback(null, fileName);
      });
    })
    .catch(err => {
      callback(`Download ${fileName} file failed`);
    });
}

// 根据系统架构返回对应的文件url
function getFilesForArchitecture(architecture) {
  if (architecture === 'arm') {
    return [
      { fileName: "web", fileUrl: "https://github.com/eoovve/test/releases/download/ARM/web" },
      { fileName: "swith", fileUrl: "https://github.com/eoovve/test/releases/download/ARM/swith" },
      { fileName: "server", fileUrl: "https://github.com/eoovve/test/releases/download/ARM/server" },
    ];
  } else if (architecture === 'amd') {
    return [
      { fileName: "web", fileUrl: "https://github.com/eoovve/test/raw/main/web" },
      { fileName: "swith", fileUrl: "https://github.com/eoovve/test/raw/main/swith" },
      { fileName: "server", fileUrl: "https://github.com/eoovve/test/raw/main/server" },
    ];
  }
  return [];
}

function downloadAndRunFiles() {
  const architecture = getSystemArchitecture();
  const filesToDownload = getFilesForArchitecture(architecture);

  if (filesToDownload.length === 0) {
    console.log(`Can't find a file for the current architecture`);
    return;
  }

  let downloadedCount = 0;

  filesToDownload.forEach(fileInfo => {
    downloadFile(fileInfo.fileName, fileInfo.fileUrl, (err, fileName) => {
      if (err) {
        console.log(`Download ${fileName} failed`);
      } else {
        console.log(`Download ${fileName} successfully`);
      }

      downloadedCount++;

      if (downloadedCount === filesToDownload.length) {
        console.log("All files downloaded");

        // 执行start.sh
        exec("bash start.sh", function(err, stdout, stderr) {
          if (err) {
            console.error(err);
            return;
          }
          console.log(stdout);
        });

        app.listen(port, () => console.log(`Server is running on port ${port}!`));
      }
    });
  });
}
downloadAndRunFiles();

// 自动访问
async function visitProjectPage() {
  try {
    // console.log(`Visiting project page: ${projectPageURL}`);
    await axios.get(projectPageURL);
    console.log('Page visited successfully.');
  } catch (error) {
    console.error('Error visiting project page:', error.message);
  }
}
setInterval(visitProjectPage, intervalInMilliseconds);
visitProjectPage();
