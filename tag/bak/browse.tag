<browse role="tabpanel" class="tab-pane" id="{opts.id}">
    <div class="row">
        <ol class="breadcrumb">
            <li each="{name, index in breadcrumb}"><a class="pathName" onclick="{goBack.bind(this,index)}">{name}</a></li>
            <div class="pull-right">
                <div class="btn-group">
                    <button type="button" class="btn btn-primary dropdown-toggle btn-xs" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                        New <span class="caret"></span>
                    </button>
                    <ul class="dropdown-menu">
                        <li><a href="#" onclick="{newFolder}"><i class="fa fa-folder fa-fw"></i> Folder</a></li>
                        <li><a href="#" onclick="{newFile}"><i class="fa fa-file fa-fw"></i> File</a></li>
                    </ul>
                </div>
            </div>
        </ol>
    </div>

    <div class="row">
        <table class="table table-responsive">
            <thead>
            <tr>
                <th>Name</th>
                <!--<th class="hidden-xs">Size</th>-->
                <!--<th class="hidden-xs text-right">Modified</th>-->
                <th></th>
            </tr>
            </thead>
            <tbody>
            <tr each="{dirEntries}">
                <td>
                    <i class="fa { isDir ? 'fa-folder' : 'fa-file'}"></i>
                    <a class="pathName" onclick="{isDir ? scanDir.bind(this,path) : openFile.bind(this,path)}">
                        <i class="fa fa-level-up" show="{path == '..'}"></i> {name}
                    </a>
                </td>
                <!--<td class="hidden-xs col-size">{size}</td>-->
                <!--<td class="hidden-xs text-right col-modified">{modifiedAt}</td>-->
                <td class="text-right col-button">
                    <button title="rename" class="btn btn-primary btn-xs" show="{path !== '..'}" onclick="{confirmRename.bind(this,path)}">✎</button>
                    <button title="delete" class="btn btn-danger btn-xs" show="{path !== '..'}" onclick="{confirmDelete.bind(this,path)}">✖</button>
                </td>
            </tr>
            </tbody>
        </table>
    </div>

    <script>
        var me = this;
        var Fs = require('fs');
        var Path = require('path');
        var root = $(me.root);

        var Moment = require('moment');
        var RimRaf = require('rimraf');

        var baseFolder = opts.dir.split(Path.sep).pop();
        var baseName = Path.dirname(opts.dir);
        var rootPath = Path.join(baseName, baseFolder);
        var curPath = rootPath;

        var ignoreDir = ['.git', '__PUBLIC', '.gitignore'];
        me.dirEntries = [];
        me.breadcrumb = [baseFolder];

        me.on('mount', function () {
        });

        function humanizeFileSize(size) {
            var i = Math.floor(Math.log(size) / Math.log(1024));
            return ( size / Math.pow(1024, i) ).toFixed(2) * 1 + ' ' + ['B', 'kB', 'MB', 'GB', 'TB'][i];
        }

        me.goBack = function (n) {
            n = me.breadcrumb.length - n - 1;
            var dir = '';
            while (n > 0) {
                dir = Path.join(dir, '..');
                n -= 1;
            }
            me.scanDir(dir);
        };

        me.openFile = function (filePath) {
            console.log('openFile', filePath);
            me.parent.openFile(Path.join(curPath, filePath));
        };

        me.confirmDelete = function (filePath) {
            bootbox.confirm(`Are you sure you want to delete "${filePath}" ?`, function (ok) {
                if (!ok) return;
                RimRaf.sync(Path.join(curPath, filePath), {glob: false});
                me.scanDir('');
            });
        };

        me.confirmRename = function (filePath) {
            bootbox.prompt({
                title:    `Write down the new name of "${filePath}".`,
                value:    filePath,
                callback: function (newName) {
                    if (newName === null || newName === filePath)
                        return;

                    Fs.renameSync(Path.join(curPath, filePath), Path.join(curPath, newName));
                    me.scanDir('');
                }
            });
        };

        me.newFile = function () {
            bootbox.prompt({
                title:    `Write down the new file name`,
                value:    '',
                callback: function (fileName) {
                    try {
                        if (fileName === null) return;
                        fileName = fileName.trim();
                        if (fileName === '') return;
//                        if (!fileName.endsWith('.md'))
//                            fileName = fileName + '.md';
                        var fd = Fs.openSync(Path.join(curPath, fileName), 'wx');
                        me.scanDir('');
                        Fs.close(fd);
                    } catch (ex) {
                        bootbox.alert(ex.message);
                    }
                }
            });
        };

        me.newFolder = function () {
            bootbox.prompt({
                title:    `Write down the new folder name`,
                value:    '',
                callback: function (folderName) {
                    try {
                        if (folderName === null) return;
                        folderName = folderName.trim();
                        if (folderName === '') return;
                        Fs.mkdirSync(Path.join(curPath, folderName));
                        me.scanDir('');
                    } catch (ex) {
                        bootbox.alert(ex.message);
                    }
                }
            });
        };

        me.scanDir = function (dir) {
//            console.log('scan dir', dir);
            if (ignoreDir.indexOf(dir) != -1) return;
            curPath = Path.join(curPath, dir);
//            console.log('scan dir curPath', curPath);

            if (dir === '..') me.breadcrumb.pop();
            else if (dir !== '') me.breadcrumb.push(dir);

            var files = [];
            me.dirEntries = [];
            // them .. neu khong phai la rootPath
            if (curPath !== rootPath) {
                me.dirEntries.push({
                    name:       'up',
                    isDir:      true,
                    path:       '..',
                    modifiedAt: ''
                });
            }

            for (var name of Fs.readdirSync(curPath)) {
                if (ignoreDir.indexOf(name) != -1) continue;
                var fullPath = Path.join(curPath, name);
                var stat = Fs.statSync(fullPath);

                var entry = {
                    name:       name,
                    isDir:      stat.isDirectory(),
                    path:       name,
                    modifiedAt: Moment(stat.mtime).fromNow()
                };

                if (stat.size === 0)
                    entry.size = '';
                else
                    entry.size = humanizeFileSize(stat.size);

                // add folder vo danh sach truoc
                if (entry.isDir) {
                    me.dirEntries.push(entry);
                } else {
                    files.push(entry);
                }
            }
            // add list files vo danh sanh dirEntries
            me.dirEntries.push.apply(me.dirEntries, files);
            me.update();
        };

        me.scanDir('');
    </script>
</browse>
