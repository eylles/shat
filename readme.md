# Shat

somewhat of a bat in sh

## why ?

why not, [awkat](https://github.com/eylles/awkat) is already a thing


## usage

just run make to install or uninstall, all this depends on is a shell interpreter and a highlighter program like [highlight](http://www.andre-simon.de/doku/highlight/highlight.php) or [source-highlight](https://www.gnu.org/software/src-highlite/), alternatively you can provide your own highlighter command with the `HIGHLIGHTER` env var

in debian and derivates just run:
```sh
sudo apt install highlight
```
or
```sh
sudo apt install source-highlight
```

in arch and derivates:
```sh
sudo pacman -S highlight
```
or
```sh
sudo pacman -S source-highlight
